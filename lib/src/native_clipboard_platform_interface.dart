import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'clipboard_image.dart';
import 'native_clipboard_method_channel.dart';

/// The interface every platform implementation of `native_clipboard` answers.
abstract class NativeClipboardPlatform extends PlatformInterface {
  NativeClipboardPlatform() : super(token: _token);

  static final Object _token = Object();

  static NativeClipboardPlatform _instance = MethodChannelNativeClipboard();

  static NativeClipboardPlatform get instance => _instance;

  /// Platform-specific implementations should set this on registration, and
  /// tests may set it to a fake — [PlatformInterface] keeps anything that is
  /// not one of ours out.
  static set instance(NativeClipboardPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Whether the clipboard holds at least one image.
  ///
  /// Deliberately separate from [getImage]: on iOS this answers without
  /// reading the clipboard, so it does not raise the system paste banner.
  Future<bool> hasImage() {
    throw UnimplementedError('hasImage() has not been implemented.');
  }

  /// The first image on the clipboard, or null if there is none.
  Future<ClipboardImage?> getImage() {
    throw UnimplementedError('getImage() has not been implemented.');
  }

  /// Every image on the clipboard, oldest item first.
  ///
  /// Only iOS ever returns more than one; Android's clipboard holds a single
  /// clip, so the list is empty or has one entry.
  Future<List<ClipboardImage>> getImages() {
    throw UnimplementedError('getImages() has not been implemented.');
  }

  /// Puts an encoded image on the clipboard, replacing what was there.
  Future<void> copyImage(ClipboardImage image) {
    throw UnimplementedError('copyImage() has not been implemented.');
  }

  /// Empties the clipboard.
  Future<void> clear() {
    throw UnimplementedError('clear() has not been implemented.');
  }
}
