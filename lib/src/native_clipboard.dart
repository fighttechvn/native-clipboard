import 'package:flutter/services.dart';

import 'clipboard_image.dart';
import 'native_clipboard_platform_interface.dart';

/// The system clipboard, including the part of it Flutter cannot reach.
///
/// Flutter's own [Clipboard] carries text and nothing else, so an image copied
/// from a browser, a screenshot, or another app is invisible to a Flutter app
/// even though the system is holding it. This reads that image.
///
/// Text is not taken over: [getText] and [setText] hand straight to
/// [Clipboard], so an app can use this class for everything the clipboard
/// holds without the copy and paste it already has behaving any differently.
///
/// A platform with no implementation of this plugin — the web, desktop, a
/// widget test with no mock — reports an empty clipboard rather than throwing,
/// so `Ctrl+V` on such a platform simply pastes text as it always did.
abstract final class NativeClipboard {
  static NativeClipboardPlatform get _platform =>
      NativeClipboardPlatform.instance;

  /// Whether the clipboard holds at least one image.
  ///
  /// On iOS this is answered without reading the clipboard, so it does not
  /// raise the "Pasted from …" banner that [getImage] does. Ask this first
  /// when all you need is whether to offer a *Paste image* button.
  static Future<bool> hasImage() async {
    try {
      return await _platform.hasImage();
    } on MissingPluginException {
      return false;
    }
  }

  /// The first image on the clipboard, or null if it holds none.
  ///
  /// On iOS 16 and up, reading the clipboard the user did not explicitly paste
  /// into the app shows the system paste banner. Calling this from a *Paste*
  /// the user tapped is what the banner is for; calling it on a timer is what
  /// it is against.
  static Future<ClipboardImage?> getImage() async {
    try {
      return await _platform.getImage();
    } on MissingPluginException {
      return null;
    }
  }

  /// Every image on the clipboard, oldest item first.
  ///
  /// iOS can hold several — a multi-select share from Photos — and Android
  /// holds one clip, so there this is [getImage] in a list.
  static Future<List<ClipboardImage>> getImages() async {
    try {
      return await _platform.getImages();
    } on MissingPluginException {
      return const [];
    }
  }

  /// Puts an encoded image on the clipboard, replacing what was there.
  ///
  /// [mimeType] is what [bytes] actually are; the platforms hand it to other
  /// apps as the type of the clip, and a wrong one makes the paste fail in an
  /// app that trusts it.
  static Future<void> copyImage(
    Uint8List bytes, {
    String mimeType = 'image/png',
  }) {
    return _platform.copyImage(
      ClipboardImage(bytes: bytes, mimeType: mimeType),
    );
  }

  /// Empties the clipboard, images and text alike.
  static Future<void> clear() => _platform.clear();

  /// The text on the clipboard — Flutter's own [Clipboard], unchanged.
  static Future<String?> getText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);

    return data?.text;
  }

  /// Copies text — Flutter's own [Clipboard], unchanged.
  static Future<void> setText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
