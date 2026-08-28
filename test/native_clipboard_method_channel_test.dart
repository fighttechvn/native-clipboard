import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_clipboard/native_clipboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelNativeClipboard();
  final bytes = Uint8List.fromList([9, 8, 7]);
  final calls = <MethodCall>[];

  /// Answers the plugin channel the way the platforms do.
  void answer(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (call) async {
          calls.add(call);

          return handler(call);
        });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);
  });

  test('hasImage passes the platform answer through', () async {
    answer((_) => true);
    expect(await platform.hasImage(), isTrue);

    answer((_) => false);
    expect(await platform.hasImage(), isFalse);
  });

  test('a platform that answers nothing holds no image', () async {
    answer((_) => null);

    expect(await platform.hasImage(), isFalse);
  });

  test('getImage reads the map the platform sends', () async {
    answer((_) => {'bytes': bytes, 'mimeType': 'image/png', 'width': 4});

    final image = await platform.getImage();

    expect(image?.bytes, bytes);
    expect(image?.mimeType, 'image/png');
    expect(image?.width, 4);
  });

  test('an empty clipboard is no image, not an error', () async {
    answer((_) => null);

    expect(await platform.getImage(), isNull);
  });

  test('getImages drops the items that turned out not to be images', () async {
    answer(
      (_) => [
        {'bytes': bytes, 'mimeType': 'image/png'},
        {'mimeType': 'image/png'},
        {'bytes': bytes, 'mimeType': 'image/jpeg'},
      ],
    );

    final images = await platform.getImages();

    expect(images, hasLength(2));
    expect(images.map((e) => e.mimeType), ['image/png', 'image/jpeg']);
  });

  test('copyImage hands over the bytes and what they are', () async {
    answer((_) => null);

    await platform.copyImage(
      ClipboardImage(bytes: bytes, mimeType: 'image/png'),
    );

    expect(calls.single.method, 'copyImage');
    expect(calls.single.arguments, {'bytes': bytes, 'mimeType': 'image/png'});
  });

  test('clear asks the platform to clear', () async {
    answer((_) => null);

    await platform.clear();

    expect(calls.single.method, 'clear');
  });

  test('a platform with no plugin registered reports an empty clipboard', () async {
    // No mock handler: this is the web, desktop, or a widget test — the call
    // fails with MissingPluginException and the facade absorbs it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, null);

    expect(await NativeClipboard.hasImage(), isFalse);
    expect(await NativeClipboard.getImage(), isNull);
    expect(await NativeClipboard.getImages(), isEmpty);
  });
}
