import Flutter
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Reads images off the iOS pasteboard and puts them back on it.
///
/// Unlike Android, iOS holds the bytes themselves, and can hold several items
/// at once — a multi-select copy out of Photos. Each item is a bag of
/// representations of the same thing, so an image copied from Safari may be
/// there as PNG, JPEG and a URL all at once; the best one is picked and handed
/// over untouched.
///
/// Reading the pasteboard is what raises the "Pasted from …" banner on iOS 16
/// and up. `hasImage` does not read it — it asks UIKit whether an image is
/// there, which is not disclosed to the user — so an app can decide whether to
/// offer a *Paste* button without the banner appearing every time.
public class NativeClipboardPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.fighttech/native_clipboard"
  private static let jpegQuality: CGFloat = 0.9

  /// The image types worth reading, best first: whatever is losslessly there
  /// beats something that has already been through a JPEG encoder.
  private static let imageTypes: [String] = [
    "public.png",
    "public.heic",
    "public.heif",
    "com.compuserve.gif",
    "org.webmproject.webp",
    "public.jpeg",
    "public.tiff",
    "com.microsoft.bmp",
    "public.image",
  ]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger())

    registrar.addMethodCallDelegate(NativeClipboardPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasImage":
      result(UIPasteboard.general.hasImages)

    case "getImage":
      result(readImages().first)

    case "getImages":
      result(readImages())

    case "copyImage":
      guard let arguments = call.arguments as? [String: Any],
        let bytes = arguments["bytes"] as? FlutterStandardTypedData,
        !bytes.data.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid_argument",
            message: "copyImage needs the image bytes",
            details: nil))
        return
      }

      let mimeType = arguments["mimeType"] as? String ?? "image/png"
      copyImage(data: bytes.data, mimeType: mimeType)
      result(nil)

    case "clear":
      UIPasteboard.general.items = []
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Every image on the pasteboard, in the order it holds them.
  private func readImages() -> [[String: Any]] {
    let pasteboard = UIPasteboard.general

    let images = pasteboard.items.compactMap(readItem)
    if !images.isEmpty {
      return images
    }

    // Nothing on the item was a type we know, but UIKit says there is an
    // image there — so it is one only UIKit can produce, and the only way to
    // read it is the way this plugin originally read everything: as a UIImage,
    // encoded to JPEG.
    guard pasteboard.hasImages, let image = pasteboard.image,
      let data = image.jpegData(compressionQuality: Self.jpegQuality)
    else {
      return []
    }

    return [
      self.image(
        data: data,
        mimeType: "image/jpeg",
        width: Int(image.size.width * image.scale),
        height: Int(image.size.height * image.scale))
    ]
  }

  /// The best image representation of one pasteboard item.
  private func readItem(_ item: [String: Any]) -> [String: Any]? {
    for type in Self.imageTypes {
      guard let value = item[type] else {
        continue
      }

      if let data = value as? Data, !data.isEmpty {
        let size = imageSize(of: data)

        return image(
          data: data,
          mimeType: mimeType(for: type),
          width: size?.width,
          height: size?.height)
      }

      // A `UIImage` on the pasteboard has no encoded form to hand over, so it
      // is encoded here.
      if let uiImage = value as? UIImage,
        let data = uiImage.jpegData(compressionQuality: Self.jpegQuality)
      {
        return image(
          data: data,
          mimeType: "image/jpeg",
          width: Int(uiImage.size.width * uiImage.scale),
          height: Int(uiImage.size.height * uiImage.scale))
      }
    }

    return nil
  }

  /// The pixel size, read from the file's header rather than by decoding it.
  private func imageSize(of data: Data) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
        as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else {
      return nil
    }

    return (width, height)
  }

  private func copyImage(data: Data, mimeType: String) {
    UIPasteboard.general.setData(data, forPasteboardType: type(for: mimeType))
  }

  private func image(
    data: Data,
    mimeType: String,
    width: Int?,
    height: Int?
  ) -> [String: Any] {
    var image: [String: Any] = [
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": mimeType,
    ]
    image["width"] = width
    image["height"] = height

    return image
  }

  /// The MIME type Dart is given for a pasteboard type.
  private func mimeType(for type: String) -> String {
    if #available(iOS 14.0, *), let mimeType = UTType(type)?.preferredMIMEType {
      return mimeType
    }

    switch type {
    case "public.png": return "image/png"
    case "public.heic", "public.heif": return "image/heic"
    case "com.compuserve.gif": return "image/gif"
    case "org.webmproject.webp": return "image/webp"
    case "public.tiff": return "image/tiff"
    case "com.microsoft.bmp": return "image/bmp"
    default: return "image/jpeg"
    }
  }

  /// The pasteboard type an image of this MIME type is put on the pasteboard
  /// as. Anything unrecognised goes on as PNG rather than as nothing: a wrong
  /// type is a paste that fails in the receiving app.
  private func type(for mimeType: String) -> String {
    if #available(iOS 14.0, *),
      let type = UTType(mimeType: mimeType), type.conforms(to: .image)
    {
      return type.identifier
    }

    switch mimeType {
    case "image/jpeg", "image/jpg": return "public.jpeg"
    case "image/heic", "image/heif": return "public.heic"
    case "image/gif": return "com.compuserve.gif"
    case "image/webp": return "org.webmproject.webp"
    case "image/tiff": return "public.tiff"
    case "image/bmp": return "com.microsoft.bmp"
    default: return "public.png"
    }
  }
}
