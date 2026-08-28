package com.fighttech.native_clipboard

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * The clipboard itself belongs to the framework, so it is exercised from the
 * example's integration test on a device. What is worth pinning here is how
 * the plugin answers a call it cannot serve: run these with
 * `./gradlew testDebugUnitTest` from `example/android/`.
 */
internal class NativeClipboardPluginTest {
    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val result = Mockito.mock(MethodChannel.Result::class.java)

        NativeClipboardPlugin().onMethodCall(MethodCall("readMinds", null), result)

        Mockito.verify(result).notImplemented()
    }

    @Test
    fun onMethodCall_copyImageWithoutBytes_isAnError() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        val call = MethodCall("copyImage", mapOf("mimeType" to "image/png"))

        NativeClipboardPlugin().onMethodCall(call, result)

        Mockito.verify(result).error(
            Mockito.eq("invalid_argument"),
            Mockito.anyString(),
            Mockito.isNull()
        )
    }

    @Test
    fun onMethodCall_beforeTheEngineIsAttached_isAnEmptyClipboard() {
        val result = Mockito.mock(MethodChannel.Result::class.java)

        // A call arriving after detach has no worker to run on; it answers
        // empty rather than throwing at the Dart side.
        NativeClipboardPlugin().onMethodCall(MethodCall("hasImage", null), result)

        Mockito.verify(result).success(null)
    }
}
