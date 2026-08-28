import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_clipboard/native_clipboard.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A clipboard the test owns.
class FakeClipboardPlatform extends NativeClipboardPlatform
    with MockPlatformInterfaceMixin {
  ClipboardImage? image;
  int reads = 0;

  @override
  Future<bool> hasImage() async => image != null;

  @override
  Future<ClipboardImage?> getImage() async {
    reads++;

    return image;
  }

  @override
  Future<List<ClipboardImage>> getImages() async => [?image];

  @override
  Future<void> copyImage(ClipboardImage image) async => this.image = image;

  @override
  Future<void> clear() async => image = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeClipboardPlatform clipboard;
  final image = ClipboardImage(
    bytes: Uint8List.fromList([1, 2, 3]),
    mimeType: 'image/png',
  );

  setUp(() {
    clipboard = FakeClipboardPlatform();
    NativeClipboardPlatform.instance = clipboard;
  });

  /// What Flutter's own clipboard holds, which is where a text paste reads
  /// from.
  void setClipboardText(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.getData':
              return text == null ? null : {'text': text};
            // What the selection toolbar asks before it offers *Paste*, and
            // the reason an image on its own gets no paste button.
            case 'Clipboard.hasStrings':
              return {'value': text != null && text.isNotEmpty};
          }

          return null;
        });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// A field inside a region, with the caret in it.
  Future<TextEditingController> pumpComposer(
    WidgetTester tester, {
    required List<ClipboardImage> pasted,
    bool enabled = true,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImagePasteRegion(
            enabled: enabled,
            onImagePasted: pasted.add,
            child: TextField(
              controller: controller,
              autofocus: true,
              contextMenuBuilder: ImagePasteRegion.contextMenuBuilder,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    return controller;
  }

  Future<void> pressPaste(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets('pasting an image hands it to the app', (tester) async {
    setClipboardText(null);
    clipboard.image = image;

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(tester, pasted: pasted);

    await pressPaste(tester);

    expect(pasted, [image]);
    expect(controller.text, isEmpty, reason: 'an image is not text');
  });

  testWidgets('pasting text is still pasting text', (tester) async {
    setClipboardText('from the clipboard');

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(tester, pasted: pasted);

    await pressPaste(tester);

    expect(controller.text, 'from the clipboard');
    expect(pasted, isEmpty);
    expect(
      clipboard.reads,
      0,
      reason:
          'a text paste must not read the image clipboard, which on iOS '
          'would raise the paste banner',
    );
  });

  testWidgets('a clipboard holding both pastes the image', (tester) async {
    setClipboardText('the alt text');
    clipboard.image = image;

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(tester, pasted: pasted);

    await pressPaste(tester);

    expect(pasted, [image]);
    expect(controller.text, isEmpty);
  });

  testWidgets('a disabled region pastes text and leaves images alone', (
    tester,
  ) async {
    setClipboardText('plain text');
    clipboard.image = image;

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(
      tester,
      pasted: pasted,
      enabled: false,
    );

    await pressPaste(tester);

    expect(pasted, isEmpty);
    expect(controller.text, 'plain text');
  });

  testWidgets('the toolbar offers Paste for an image-only clipboard', (
    tester,
  ) async {
    setClipboardText(null);
    clipboard.image = image;

    final pasted = <ClipboardImage>[];
    await pumpComposer(tester, pasted: pasted);

    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    // Flutter shows no paste button at all for a clipboard with no text.
    final paste = find.text('Paste');
    expect(paste, findsOneWidget);

    await tester.tap(paste);
    await tester.pumpAndSettle();

    expect(pasted, [image]);
  });

  /// A composer on an iOS that draws the selection menu itself, which is what
  /// every iPhone on iOS 16 and up does.
  Future<EditableTextState> pumpSystemMenuComposer(
    WidgetTester tester, {
    required List<ClipboardImage> pasted,
    String text = 'Hello',
  }) async {
    final controller = TextEditingController(text: text);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        // Above the Navigator, so the Overlay the menu is built in sees it —
        // which is where a real app's MediaQuery sits too.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(supportsShowingSystemContextMenu: true),
          child: child!,
        ),
        home: Scaffold(
          body: ImagePasteRegion(
            onImagePasted: pasted.add,
            child: TextField(
              controller: controller,
              autofocus: true,
              contextMenuBuilder: ImagePasteRegion.contextMenuBuilder,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: text.length,
    );
    await tester.pump();

    final state = tester.state<EditableTextState>(find.byType(EditableText));
    state.showToolbar();
    await tester.pumpAndSettle();

    return state;
  }

  List<IOSSystemContextMenuItem> systemMenuItems(WidgetTester tester) =>
      tester.widget<SystemContextMenu>(find.byType(SystemContextMenu)).items;

  testWidgets(
    'on iOS the menu is the one the platform draws',
    (tester) async {
      setClipboardText(null);
      clipboard.image = image;

      final pasted = <ClipboardImage>[];
      await pumpSystemMenuComposer(tester, pasted: pasted);

      // A Flutter toolbar here is a second menu drawn over the platform's own,
      // which is what the field showed before: two menus, two Copy buttons.
      expect(find.byType(SystemContextMenu), findsOneWidget);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(find.text('Copy'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'the system menu pastes an image from where Paste belongs',
    (tester) async {
      setClipboardText(null);
      clipboard.image = image;

      final pasted = <ClipboardImage>[];
      await pumpSystemMenuComposer(tester, pasted: pasted);

      final items = systemMenuItems(tester);
      expect(
        items.map((e) => e.runtimeType.toString()),
        containsAllInOrder([
          'IOSSystemContextMenuItemCut',
          'IOSSystemContextMenuItemCopy',
          'IOSSystemContextMenuItemCustom',
        ]),
        reason:
            'Paste goes straight after Copy, where the platform puts it — last '
            'is behind the overflow arrow, where it reads as missing',
      );

      final paste = items.whereType<IOSSystemContextMenuItemCustom>().single;
      expect(paste.title, 'Paste');

      paste.onPressed();
      await tester.pumpAndSettle();

      expect(pasted, [image]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'a clipboard with no image leaves the system menu alone',
    (tester) async {
      setClipboardText('some text');
      clipboard.image = null;

      final pasted = <ClipboardImage>[];
      final state = await pumpSystemMenuComposer(tester, pasted: pasted);

      expect(
        systemMenuItems(tester),
        SystemContextMenu.getDefaultItems(state),
        reason:
            "nothing to add, so nothing is touched: the platform's own Paste "
            'pastes text without raising the iOS paste banner',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('Paste is offered where the field would have had it', (
    tester,
  ) async {
    setClipboardText(null);
    clipboard.image = image;

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(tester, pasted: pasted);
    controller.text = 'Hello';
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();

    tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
    await tester.pumpAndSettle();

    expect(
      find.byType(Text).evaluate().map((e) => (e.widget as Text).data).toList(),
      containsAllInOrder(['Cut', 'Copy', 'Paste']),
      reason: 'a Paste tacked on at the end is hidden behind the overflow',
    );
  });

  testWidgets('the toolbar keeps the buttons the field already had', (
    tester,
  ) async {
    setClipboardText('some text');

    final pasted = <ClipboardImage>[];
    final controller = await pumpComposer(tester, pasted: pasted);
    controller.text = 'written already';

    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Select all'), findsOneWidget);
    expect(find.text('Paste'), findsOneWidget);

    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();

    expect(controller.text, contains('some text'));
    expect(pasted, isEmpty);
  });
}
