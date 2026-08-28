import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'clipboard_image.dart';
import 'native_clipboard_platform_interface.dart';

/// The [NativeClipboardPlatform] both platforms are reached through.
///
/// Android and iOS answer the same method names with the same shapes, so one
/// channel implementation serves both.
class MethodChannelNativeClipboard extends NativeClipboardPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('com.fighttech/native_clipboard');

  @override
  Future<bool> hasImage() async {
    final hasImage = await methodChannel.invokeMethod<bool>('hasImage');

    return hasImage ?? false;
  }

  @override
  Future<ClipboardImage?> getImage() async {
    final image = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getImage',
    );

    return ClipboardImage.fromMap(image);
  }

  @override
  Future<List<ClipboardImage>> getImages() async {
    final images = await methodChannel.invokeListMethod<Object?>('getImages');

    return [
      for (final image in images ?? const []) ?ClipboardImage.fromMap(image),
    ];
  }

  @override
  Future<void> copyImage(ClipboardImage image) {
    return methodChannel.invokeMethod<void>('copyImage', {
      'bytes': image.bytes,
      'mimeType': image.mimeType,
    });
  }

  @override
  Future<void> clear() => methodChannel.invokeMethod<void>('clear');
}
