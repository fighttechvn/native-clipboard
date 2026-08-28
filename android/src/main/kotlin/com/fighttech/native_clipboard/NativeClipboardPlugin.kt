package com.fighttech.native_clipboard

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result as FlutterResult
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Reads images off the Android clipboard and puts them back on it.
 *
 * Android holds one clip at a time, and an image in it is a `content://` URI
 * pointing at the app that did the copying — not the bytes. Reading it means
 * opening that URI through the resolver, which only works while this app has
 * window focus: from Android 10 on, a background app reading the clipboard
 * gets nothing back. Every read here is therefore expected to be driven by
 * something the user just did.
 */
class NativeClipboardPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    /** Decoding a screenshot is far too slow for the platform thread. */
    private var worker: ExecutorService? = null
    // Built on first use rather than on construction, so that a JVM unit test
    // can make a plugin without a mocked Looper.
    private val main by lazy { Handler(Looper.getMainLooper()) }

    private val clipboard: ClipboardManager
        get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        worker = Executors.newSingleThreadExecutor()
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        worker?.shutdown()
        worker = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: FlutterResult
    ) {
        when (call.method) {
            "hasImage" -> onWorker(result) { hasImage() }

            // Android's clipboard holds a single clip, so the first image is
            // every image; `getImages` answers with a list of none or one.
            "getImage" -> onWorker(result) { readImages().firstOrNull() }
            "getImages" -> onWorker(result) { readImages() }

            "copyImage" -> {
                val bytes = call.argument<ByteArray>("bytes")
                if (bytes == null || bytes.isEmpty()) {
                    result.error("invalid_argument", "copyImage needs the image bytes", null)
                    return
                }
                val mimeType = call.argument<String>("mimeType") ?: DEFAULT_MIME_TYPE
                onWorker(result) { copyImage(bytes, mimeType) }
            }

            "clear" -> onWorker(result) { clear() }

            else -> result.notImplemented()
        }
    }

    /**
     * Runs [work] off the platform thread and answers on it.
     *
     * A clipboard the app cannot read is an empty clipboard, not a failure —
     * the owning app may have been uninstalled, or revoked the grant, and
     * neither is worth an exception on the Dart side. Anything else is
     * reported as it happened.
     */
    private fun onWorker(
        result: FlutterResult,
        work: () -> Any?
    ) {
        val worker = this.worker
        if (worker == null || worker.isShutdown) {
            result.success(null)
            return
        }

        worker.execute {
            val answer =
                try {
                    Result.success(work())
                } catch (e: SecurityException) {
                    Result.success(null)
                } catch (e: Exception) {
                    Result.failure<Any?>(e)
                }

            main.post {
                answer.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        result.error("clipboard_error", it.message, it.stackTraceToString())
                    }
                )
            }
        }
    }

    /**
     * Whether the clip holds an image, answered without opening it.
     *
     * The description is the cheap half of the clipboard: it names the types
     * of the clip without reading a byte of it. Some apps describe an image
     * only as a URI, so a clip carrying one is asked what it points at.
     */
    private fun hasImage(): Boolean {
        if (!clipboard.hasPrimaryClip()) {
            return false
        }

        val description = clipboard.primaryClipDescription ?: return false
        if (description.hasMimeType("image/*")) {
            return true
        }

        val uri = clipboard.primaryClip?.imageUris().orEmpty()

        return uri.isNotEmpty()
    }

    private fun readImages(): List<Map<String, Any?>> {
        if (!clipboard.hasPrimaryClip()) {
            return emptyList()
        }

        val clip = clipboard.primaryClip ?: return emptyList()

        return clip.imageUris().mapNotNull { readImage(it) }
    }

    /** Every item of the clip that points at an image. */
    private fun ClipData.imageUris(): List<Uri> =
        (0 until itemCount)
            .mapNotNull { getItemAt(it).uri }
            .filter { uri ->
                val type = runCatching { context.contentResolver.getType(uri) }.getOrNull()

                type?.startsWith("image/") == true ||
                    // A file:// URI has no resolver type; the description said
                    // it was an image, and the decode below is the real check.
                    (type == null && description.hasMimeType("image/*"))
            }

    /**
     * The image behind a clipboard URI.
     *
     * Handing back the bytes the other app stored is both faster and truer
     * than decoding them: a copied PNG keeps its transparency, an animated GIF
     * stays animated, and nothing is re-compressed. Only an image the resolver
     * will not name — or one whose bytes turn out not to decode — takes the
     * long way round, through a bitmap and back out as JPEG.
     */
    private fun readImage(uri: Uri): Map<String, Any?>? {
        val resolver = context.contentResolver
        val bytes =
            try {
                resolver.openInputStream(uri)?.use { it.readBytes() }
            } catch (e: Exception) {
                null
            } ?: return null

        if (bytes.isEmpty()) {
            return null
        }

        val bounds =
            BitmapFactory.Options().apply {
                inJustDecodeBounds = true
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, this)
            }

        // `outMimeType` is what the bytes are; the resolver's type is what the
        // other app says they are, and the bytes win where they disagree.
        val mimeType = bounds.outMimeType ?: resolver.getType(uri)

        if (bounds.outWidth > 0 && bounds.outHeight > 0 && mimeType != null) {
            return image(bytes, mimeType, bounds.outWidth, bounds.outHeight)
        }

        return reencode(uri)
    }

    /**
     * The original path this plugin grew out of: decode whatever the URI
     * points at into a bitmap and hand it back as JPEG.
     *
     * It is the fallback rather than the rule because it costs a full decode
     * and loses both transparency and a little quality — but it is the only
     * thing that reads an image the platform will only give up as a bitmap.
     */
    private fun reencode(uri: Uri): Map<String, Any?>? {
        val bitmap =
            context.contentResolver.openInputStream(uri)?.use {
                BitmapFactory.decodeStream(it)
            } ?: return null

        return try {
            ByteArrayOutputStream().use { stream ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, stream)

                image(stream.toByteArray(), "image/jpeg", bitmap.width, bitmap.height)
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun image(
        bytes: ByteArray,
        mimeType: String,
        width: Int,
        height: Int
    ): Map<String, Any?> =
        mapOf(
            "bytes" to bytes,
            "mimeType" to mimeType,
            "width" to width,
            "height" to height
        )

    /**
     * Puts an image on the clipboard.
     *
     * A clip carries a URI, never bytes, so the image is written to this app's
     * cache and shared through the provider declared in the plugin's manifest.
     * Whoever pastes it reads it back through that provider, which is why the
     * clip is granted read permission and the file is left in place: deleting
     * it would empty the clipboard from the other app's point of view.
     */
    private fun copyImage(
        bytes: ByteArray,
        mimeType: String
    ) {
        val directory = File(context.cacheDir, CACHE_DIRECTORY).apply { mkdirs() }

        // One name, overwritten: the clipboard holds one image at a time, and
        // a file per copy would grow without anything ever clearing it.
        val file = File(directory, "clipboard_image.${mimeType.fileExtension()}")
        file.writeBytes(bytes)

        val authority = "${context.packageName}.native_clipboard.fileprovider"
        val uri = FileProvider.getUriForFile(context, authority, file)

        clipboard.setPrimaryClip(
            ClipData.newUri(context.contentResolver, "Image", uri)
        )
    }

    private fun String.fileExtension(): String =
        when (this) {
            "image/png" -> "png"
            "image/gif" -> "gif"
            "image/webp" -> "webp"
            "image/heic", "image/heif" -> "heic"
            "image/bmp" -> "bmp"
            else -> "jpg"
        }

    private fun clear() {
        // `clearPrimaryClip` is API 28 and up; below it, an empty clip is the
        // closest the platform gets to an empty clipboard.
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            clipboard.clearPrimaryClip()
        } else {
            clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
        }
    }

    private companion object {
        const val CHANNEL = "com.fighttech/native_clipboard"
        const val CACHE_DIRECTORY = "native_clipboard"
        const val DEFAULT_MIME_TYPE = "image/png"
        const val JPEG_QUALITY = 90
    }
}
