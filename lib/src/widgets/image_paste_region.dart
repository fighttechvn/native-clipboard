import 'dart:async';

import 'package:flutter/material.dart';

import '../clipboard_image.dart';
import '../native_clipboard.dart';

/// Called with an image the user pasted into a text field.
typedef ClipboardImagePasted = void Function(ClipboardImage image);

/// Lets the text fields under it accept a pasted image.
///
/// Flutter's clipboard carries text, so pasting a screenshot into a `TextField`
/// does nothing at all: the keystroke is swallowed and no image arrives.
/// Wrapping the field in an [ImagePasteRegion] gives the paste somewhere to go
/// — [onImagePasted] is called with the image, and the app decides what a
/// pasted image means, usually an attachment above the composer.
///
/// ```dart
/// ImagePasteRegion(
///   onImagePasted: (image) => setState(() => _attachment = image),
///   child: TextField(
///     contextMenuBuilder: ImagePasteRegion.contextMenuBuilder,
///   ),
/// )
/// ```
///
/// Nothing the fields already do changes. Copy, cut, select all and — when the
/// clipboard holds no image — paste are the ones Flutter installed, reached
/// through the same keystrokes and the same selection toolbar. Only a paste of
/// something Flutter could not have pasted anyway is taken over: an image on
/// the clipboard is handed to [onImagePasted] instead of being dropped, and a
/// clipboard holding both an image and text pastes the image.
///
/// Two things have to be covered for a paste to feel native, and they are
/// reached differently:
///
///  * `Ctrl+V` / `Cmd+V`, and any other route through `PasteTextIntent`, is
///    handled by an [Actions] override this widget installs. Nothing is needed
///    at the field for it.
///  * The selection toolbar builds its own buttons and never goes through
///    `Actions`, so a field that should offer *Paste* there has to be given
///    [contextMenuBuilder]. It is worth doing: with an image on the clipboard
///    and no text, Flutter shows no paste button at all.
class ImagePasteRegion extends StatefulWidget {
  /// Called with the pasted image, on the platform thread's next turn.
  final ClipboardImagePasted onImagePasted;

  /// Whether a pasted image is taken. When false every paste is the plain text
  /// one, which is how a composer that has run out of room for attachments can
  /// stop accepting images without being taken apart.
  final bool enabled;

  final Widget child;

  const ImagePasteRegion({
    super.key,
    required this.onImagePasted,
    required this.child,
    this.enabled = true,
  });

  /// Hands a `TextField` a selection menu whose *Paste* also pastes images.
  ///
  /// Pass it as `contextMenuBuilder:` to any field inside an
  /// [ImagePasteRegion]; outside one it builds the menu Flutter would have
  /// built, so it is safe on a field that is sometimes wrapped and sometimes
  /// not.
  ///
  /// It is the field's own menu throughout — the same menu the field builds
  /// for itself, in the same order and with the same look. On iOS 16 and up
  /// that is the menu UIKit draws, which is what a `TextField` shows when it
  /// is left alone; everywhere else it is Flutter's toolbar. Only *Paste* is
  /// touched, and only when there is an image to paste: a *Paste* Flutter left
  /// out because the clipboard holds no text is put back where the field would
  /// have had it, and a clipboard holding an image pastes the image.
  static Widget contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    // The menu is built inside the Overlay, which sits above the region — so
    // the region is looked up from the field, which sits below it.
    final region = _ImagePasteScope.maybeOf(editableTextState.context);

    // What the field would have shown on its own. Both halves of this are the
    // default `contextMenuBuilder` of `TextField`, kept in step with it: on
    // iOS the system menu is not a Flutter widget at all, and drawing a
    // Flutter toolbar in its place is a second menu over the platform's own.
    if (SystemContextMenu.isSupportedByField(editableTextState)) {
      final items = SystemContextMenu.getDefaultItems(editableTextState);

      return SystemContextMenu.editableText(
        editableTextState: editableTextState,
        items: region == null
            ? items
            : region.withImagePasteItem(context, items, editableTextState),
      );
    }

    if (region == null) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: editableTextState,
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: region.withImagePaste(
        editableTextState.contextMenuButtonItems,
        editableTextState,
      ),
    );
  }

  @override
  State<ImagePasteRegion> createState() => _ImagePasteRegionState();
}

class _ImagePasteRegionState extends State<ImagePasteRegion> {
  AppLifecycleListener? _lifecycleListener;

  /// Whether the clipboard held an image the last time we looked.
  ///
  /// The selection toolbar is built in one synchronous pass and the clipboard
  /// can only be read asynchronously, so whether to offer *Paste* has to be
  /// answered from something already known. It is read when the region is
  /// mounted and again whenever the app comes back to the foreground, which is
  /// where a copy made in another app happens.
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(onResume: _refreshHasImage);
    _refreshHasImage();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    super.dispose();
  }

  Future<void> _refreshHasImage() async {
    final hasImage = widget.enabled && await NativeClipboard.hasImage();
    if (mounted && hasImage != _hasImage) {
      setState(() => _hasImage = hasImage);
    }
  }

  /// Takes the image off the clipboard, if there is one.
  ///
  /// Returns whether it handled the paste: false means the caller should do
  /// the plain text paste it would have done.
  Future<bool> pasteImage() async {
    if (!widget.enabled) {
      return false;
    }

    // `hasImage` does not read the clipboard, so a paste of plain text never
    // raises the iOS paste banner on its way past.
    final image = await NativeClipboard.hasImage()
        ? await NativeClipboard.getImage()
        : null;

    unawaited(_refreshHasImage());

    if (image == null || !mounted) {
      return false;
    }

    widget.onImagePasted(image);

    return true;
  }

  /// The field's own toolbar buttons, with *Paste* taught about images.
  List<ContextMenuButtonItem> withImagePaste(
    List<ContextMenuButtonItem> buttonItems,
    EditableTextState editableTextState,
  ) {
    void onPasted() {
      // The toolbar goes away on the tap, as it does for every other button;
      // waiting for the clipboard first would leave it hanging over the field.
      editableTextState.hideToolbar();

      pasteImage().then((handled) {
        if (!handled) {
          editableTextState.pasteText(SelectionChangedCause.toolbar);
        }
      });
    }

    final items = [...buttonItems];
    final paste = items.indexWhere(
      (e) => e.type == ContextMenuButtonType.paste,
    );

    if (paste != -1) {
      items[paste] = items[paste].copyWith(onPressed: onPasted);

      return items;
    }

    // Flutter offers *Paste* only when the clipboard holds text, so an image
    // on its own leaves the field with no way to paste it.
    if (!_hasImage) {
      return items;
    }

    items.insert(
      _pasteSlot(
        items.map(
          (e) =>
              e.type == ContextMenuButtonType.cut ||
              e.type == ContextMenuButtonType.copy,
        ),
      ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        onPressed: onPasted,
      ),
    );

    return items;
  }

  /// The field's own *Paste* for the iOS system menu, which is not a Flutter
  /// widget and cannot be given an arbitrary button.
  ///
  /// The system's own *Paste* is left exactly where it is unless there is an
  /// image to paste: UIKit pastes text without ever raising the *Allow Paste?*
  /// banner, and a Flutter button in its place could not. Only a clipboard
  /// holding an image is worth the swap.
  List<IOSSystemContextMenuItem> withImagePasteItem(
    BuildContext context,
    List<IOSSystemContextMenuItem> items,
    EditableTextState editableTextState,
  ) {
    if (!_hasImage) {
      return items;
    }

    final image = IOSSystemContextMenuItemCustom(
      // The platform's own wording for the button it is standing in for.
      title: WidgetsLocalizations.of(context).pasteButtonLabel,
      onPressed: () {
        editableTextState.hideToolbar();

        pasteImage().then((handled) {
          if (!handled) {
            editableTextState.pasteText(SelectionChangedCause.toolbar);
          }
        });
      },
    );

    final paste = items.indexWhere((e) => e is IOSSystemContextMenuItemPaste);
    if (paste != -1) {
      return [...items]..[paste] = image;
    }

    return [...items]..insert(
      _pasteSlot(
        items.map(
          (e) =>
              e is IOSSystemContextMenuItemCut ||
              e is IOSSystemContextMenuItemCopy,
        ),
      ),
      image,
    );
  }

  /// Where *Paste* goes in a menu that has none.
  ///
  /// Straight after *Cut* and *Copy*, which is where every one of these menus
  /// puts it — putting it last instead is what pushes it off the end of the
  /// iOS toolbar and behind the overflow arrow, where it reads as missing.
  int _pasteSlot(Iterable<bool> isCutOrCopy) {
    var slot = 0;
    var index = 0;
    for (final match in isCutOrCopy) {
      index++;
      if (match) {
        slot = index;
      }
    }

    return slot;
  }

  @override
  Widget build(BuildContext context) {
    return _ImagePasteScope(
      state: this,
      hasImage: _hasImage,
      child: Actions(
        actions: {PasteTextIntent: _PasteImageAction(this)},
        child: widget.child,
      ),
    );
  }
}

/// Handles a paste on its way to the field.
///
/// Installed as an override of the field's own paste action, which Flutter
/// hands over as [callingAction] — so the text paste is not reimplemented
/// here, it is the one the field was going to run, called when the clipboard
/// turns out to hold no image.
class _PasteImageAction extends Action<PasteTextIntent> {
  final _ImagePasteRegionState _region;

  _PasteImageAction(this._region);

  @override
  Object? invoke(PasteTextIntent intent) {
    // Only valid for as long as this call: read it now, use it once the
    // clipboard has answered.
    final pasteText = callingAction;

    _region.pasteImage().then((handled) {
      if (!handled) {
        pasteText?.invoke(intent);
      }
    });

    return null;
  }
}

/// Carries the region down to the fields under it, so that
/// [ImagePasteRegion.contextMenuBuilder] can be handed over by name.
class _ImagePasteScope extends InheritedWidget {
  final _ImagePasteRegionState state;

  /// Only here so that a field which reads the scope is rebuilt when the
  /// clipboard starts or stops holding an image.
  final bool hasImage;

  const _ImagePasteScope({
    required this.state,
    required this.hasImage,
    required super.child,
  });

  /// Found without depending on it: the caller is the selection toolbar,
  /// built in the Overlay for the length of one gesture, and the element it
  /// would register the dependency against is the field's, which is rebuilt
  /// by the region itself anyway.
  static _ImagePasteRegionState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ImagePasteScope>()?.state;

  @override
  bool updateShouldNotify(_ImagePasteScope oldWidget) =>
      hasImage != oldWidget.hasImage || state != oldWidget.state;
}
