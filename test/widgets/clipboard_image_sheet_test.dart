import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_clipboard/native_clipboard.dart';

/// What the sheet resolved to, once it has closed.
class SheetResult {
  bool closed = false;
  PastedImageMessage? message;
}

void main() {
  final image = ClipboardImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/png',
  );

  /// Opens the sheet over a page and hands back the result it will fill in.
  Future<SheetResult> showSheet(WidgetTester tester) async {
    final result = SheetResult();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result.message = await showClipboardImageSheet(
                  context,
                  image: image,
                );
                result.closed = true;
              },
              child: const Text('paste'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('paste'));
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('sending returns the image and the caption', (tester) async {
    final result = await showSheet(tester);

    expect(find.text('Message Preview'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  look at this  ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    expect(result.message?.image, image);
    expect(
      result.message?.caption,
      'look at this',
      reason: 'the caption is trimmed, so a stray space is not a message',
    );
  });

  testWidgets('an image can be sent without a caption', (tester) async {
    final result = await showSheet(tester);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(result.message?.caption, isEmpty);
  });

  testWidgets('closing the sheet sends nothing', (tester) async {
    final result = await showSheet(tester);

    await tester.enterText(find.byType(TextField), 'never mind');
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(result.closed, isTrue);
    expect(result.message, isNull);
  });

  testWidgets('an image Flutter cannot decode still says what it is', (
    tester,
  ) async {
    await showSheet(tester);

    // The bytes above are not a real PNG, which is what a HEIC off an iPhone
    // looks like to Flutter.
    expect(find.text('image/png'), findsOneWidget);
  });
}
