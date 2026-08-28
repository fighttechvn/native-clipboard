// Runs against a real device: `flutter test integration_test` from example/.
//
// The clipboard here is the device's own, so this puts an image on it and
// reads it back rather than assuming what the user copied last.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:native_clipboard/native_clipboard.dart';

/// The smallest valid PNG: one transparent pixel.
final _onePixelPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(NativeClipboard.clear);

  testWidgets('an image copied to the clipboard comes back', (tester) async {
    await NativeClipboard.copyImage(_onePixelPng, mimeType: 'image/png');

    expect(await NativeClipboard.hasImage(), isTrue);

    final image = await NativeClipboard.getImage();

    expect(image, isNotNull);
    expect(image!.bytes, isNotEmpty);
    expect(image.mimeType, startsWith('image/'));
    expect(image.width, anyOf(isNull, 1));
  });

  testWidgets('a clipboard holding only text holds no image', (tester) async {
    await NativeClipboard.clear();
    await NativeClipboard.setText('not an image');

    expect(await NativeClipboard.hasImage(), isFalse);
    expect(await NativeClipboard.getImage(), isNull);
    expect(await NativeClipboard.getText(), 'not an image');
  });
}
