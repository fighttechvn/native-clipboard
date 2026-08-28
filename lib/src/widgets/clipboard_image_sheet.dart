import 'package:flutter/material.dart';

import '../clipboard_image.dart';

/// An image the user pasted, and the message they wrote to go with it.
@immutable
class PastedImageMessage {
  final ClipboardImage image;

  /// What the user typed under the preview. Empty when they sent the image on
  /// its own — never null, so a caller can hand it straight to an API that
  /// takes an optional caption.
  final String caption;

  const PastedImageMessage({required this.image, required this.caption});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PastedImageMessage &&
          other.image == image &&
          other.caption == caption;

  @override
  int get hashCode => Object.hash(image, caption);

  @override
  String toString() => 'PastedImageMessage($image, caption: "$caption")';
}

/// Shows the pasted [image] in a bottom sheet and asks for a caption.
///
/// This is the half of a paste the plugin cannot decide for an app: an image
/// arriving in a composer has to be looked at before it is sent, because a
/// paste is one keystroke and the wrong screenshot is embarrassing. The sheet
/// shows what is about to be sent, takes an optional message, and sends on the
/// user's word.
///
/// Resolves to the image and its caption when the user sends, and to null when
/// they close the sheet or swipe it away — so a paste is never sent by
/// accident.
///
/// ```dart
/// ImagePasteRegion(
///   onImagePasted: (image) async {
///     final message = await showClipboardImageSheet(context, image: image);
///     if (message != null) {
///       send(message.image, message.caption);
///     }
///   },
///   child: TextField(contextMenuBuilder: ImagePasteRegion.contextMenuBuilder),
/// )
/// ```
Future<PastedImageMessage?> showClipboardImageSheet(
  BuildContext context, {
  required ClipboardImage image,
  String title = 'Clipboard',
  String previewLabel = 'Message Preview',
  String captionHint = 'Add a caption…',
  String? initialCaption,
  bool useRootNavigator = true,
}) {
  return showModalBottomSheet<PastedImageMessage>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    // The caption field has to be able to sit above the keyboard, which a
    // sheet sized to its content cannot do.
    isScrollControlled: true,
    builder: (context) => ClipboardImageSheet(
      image: image,
      title: title,
      previewLabel: previewLabel,
      captionHint: captionHint,
      initialCaption: initialCaption,
    ),
  );
}

/// The body of [showClipboardImageSheet]: a preview, a caption field, and a
/// send button.
///
/// Shown by [showClipboardImageSheet] in the usual case; it is public for an
/// app that puts the same thing somewhere other than a modal sheet — a side
/// panel on a tablet, a page of its own. It pops the enclosing route with a
/// [PastedImageMessage] when the user sends and with null when they close, so
/// whatever shows it should be a route that can carry that result.
class ClipboardImageSheet extends StatefulWidget {
  final ClipboardImage image;
  final String title;
  final String previewLabel;
  final String captionHint;
  final String? initialCaption;

  const ClipboardImageSheet({
    super.key,
    required this.image,
    this.title = 'Clipboard',
    this.previewLabel = 'Message Preview',
    this.captionHint = 'Add a caption…',
    this.initialCaption,
  });

  @override
  State<ClipboardImageSheet> createState() => _ClipboardImageSheetState();
}

class _ClipboardImageSheetState extends State<ClipboardImageSheet> {
  late final TextEditingController _caption = TextEditingController(
    text: widget.initialCaption,
  );

  @override
  void dispose() {
    _caption.dispose();

    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _send() {
    Navigator.of(context).pop(
      PastedImageMessage(image: widget.image, caption: _caption.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);

    return Padding(
      // Lifts the caption field off the keyboard rather than being covered by
      // it, which is what a sheet with a text field in it is usually missing.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(title: widget.title, onClose: _close),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    _PreviewLabel(text: widget.previewLabel),
                    const SizedBox(height: 16),
                    _Preview(image: widget.image),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: widget.captionHint,
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: MaterialLocalizations.of(context).okButtonLabel,
                    // Painted here rather than with `IconButton.filled`: the
                    // filled variant is a Material 3 default, and an app still
                    // on Material 2 would draw the send button as a white icon
                    // on the white sheet — there, but invisible.
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _Header({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          // Balances the close button so the title sits in the middle.
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PreviewLabel extends StatelessWidget {
  final String text;

  const _PreviewLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final ClipboardImage image;

  const _Preview({required this.image});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        // Tall screenshots are the common case, and one shown whole is taller
        // than the sheet has room for; this keeps the caption field on screen.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.45,
        ),
        child: Image.memory(
          image.bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  // The type is the useful half: an image Flutter cannot
                  // decode is usually a HEIC off an iPhone.
                  image.mimeType,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
