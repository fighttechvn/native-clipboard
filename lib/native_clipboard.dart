/// Reads and writes the part of the system clipboard Flutter cannot reach.
///
/// [NativeClipboard] is the clipboard itself — images off it, images onto it,
/// and the text calls handed straight to Flutter's own `Clipboard`.
/// [ImagePasteRegion] is the feature most apps are here for: a text field the
/// user can paste a screenshot into.
library;

export 'src/clipboard_image.dart' show ClipboardImage;
export 'src/native_clipboard.dart' show NativeClipboard;
export 'src/native_clipboard_method_channel.dart'
    show MethodChannelNativeClipboard;
export 'src/native_clipboard_platform_interface.dart'
    show NativeClipboardPlatform;
export 'src/widgets/clipboard_image_sheet.dart'
    show ClipboardImageSheet, PastedImageMessage, showClipboardImageSheet;
export 'src/widgets/image_paste_region.dart'
    show ClipboardImagePasted, ImagePasteRegion;
