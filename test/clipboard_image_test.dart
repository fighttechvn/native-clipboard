import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_clipboard/native_clipboard.dart';

void main() {
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  group('fromMap', () {
    test('reads what the platforms send', () {
      final image = ClipboardImage.fromMap({
        'bytes': bytes,
        'mimeType': 'image/png',
        'width': 120,
        'height': 80,
      });

      expect(image?.bytes, bytes);
      expect(image?.mimeType, 'image/png');
      expect(image?.width, 120);
      expect(image?.height, 80);
    });

    test('a platform that could not measure the image still returns it', () {
      final image = ClipboardImage.fromMap({
        'bytes': bytes,
        'mimeType': 'image/jpeg',
      });

      expect(image?.mimeType, 'image/jpeg');
      expect(image?.width, isNull);
      expect(image?.height, isNull);
    });

    test('an unnamed type is admitted rather than guessed', () {
      final image = ClipboardImage.fromMap({'bytes': bytes});

      expect(image?.mimeType, 'application/octet-stream');
      expect(image?.fileExtension, 'bin');
    });

    test('nothing usable is no image', () {
      expect(ClipboardImage.fromMap(null), isNull);
      expect(ClipboardImage.fromMap('an image, honest'), isNull);
      expect(ClipboardImage.fromMap({'mimeType': 'image/png'}), isNull);
      expect(
        ClipboardImage.fromMap({'bytes': Uint8List(0)}),
        isNull,
        reason: 'an empty clip is an empty clipboard, not an empty image',
      );
    });
  });

  test('fileExtension names the file after what is in it', () {
    String extensionOf(String mimeType) =>
        ClipboardImage(bytes: bytes, mimeType: mimeType).fileExtension;

    expect(extensionOf('image/png'), 'png');
    expect(extensionOf('image/jpeg'), 'jpg');
    expect(extensionOf('image/gif'), 'gif');
    expect(extensionOf('image/webp'), 'webp');
    expect(extensionOf('image/heic'), 'heic');
    expect(extensionOf('application/pdf'), 'bin');
  });

  test('two reads of the same clip are the same image', () {
    final one = ClipboardImage.fromMap({
      'bytes': Uint8List.fromList([1, 2, 3, 4]),
      'mimeType': 'image/png',
    });
    final two = ClipboardImage.fromMap({
      'bytes': Uint8List.fromList([1, 2, 3, 4]),
      'mimeType': 'image/png',
    });

    expect(one, two);
    expect(one.hashCode, two.hashCode);
    expect(
      one,
      isNot(
        ClipboardImage(
          bytes: Uint8List.fromList([4, 3, 2, 1]),
          mimeType: 'image/png',
        ),
      ),
    );
  });
}
