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
  Future<SheetResult> showSheet(WidgetTester tester, {ThemeData? theme}) async {
    final result = SheetResult();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
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

  testWidgets('the send button is drawn on a Material 2 app', (tester) async {
    // Given an app that has not moved to Material 3, where the filled icon
    // button has no filled defaults to fall back on: the send button drew a
    // white icon on the white sheet and looked like it was missing.
    final result = await showSheet(
      tester,
      theme: ThemeData(
        useMaterial3: false,
        colorScheme: const ColorScheme.light(primary: Color(0xFFFAAF3A)),
      ),
    );

    // Then it paints itself, and what it paints can be read against it
    final send = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.send_rounded),
    );
    const pressed = <WidgetState>{};
    expect(
      send.style?.backgroundColor?.resolve(pressed),
      const Color(0xFFFAAF3A),
    );
    expect(
      send.style?.foregroundColor?.resolve(pressed),
      isNot(const Color(0xFFFAAF3A)),
    );

    // And it still sends
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(result.message?.image, image);
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
