import 'package:flutter/material.dart';
import 'package:native_clipboard/native_clipboard.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'native_clipboard',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F8F5F),
        useMaterial3: true,
      ),
      home: const ComposerPage(),
    );
  }
}

/// A chat composer that accepts a pasted image.
///
/// Copy a screenshot, put the caret in the field and press `Cmd+V` / `Ctrl+V`
/// — or long-press and tap *Paste*. The image comes up in a sheet with a
/// caption field, and sending it adds it to the conversation.
class ComposerPage extends StatefulWidget {
  const ComposerPage({super.key});

  @override
  State<ComposerPage> createState() => _ComposerPageState();
}

class _ComposerPageState extends State<ComposerPage> {
  final _messages = <PastedImageMessage>[];
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();

    super.dispose();
  }

  Future<void> _onImagePasted(ClipboardImage image) async {
    final message = await showClipboardImageSheet(context, image: image);
    if (message == null) {
      return;
    }

    setState(() => _messages.insert(0, message));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste an image'),
        actions: [
          IconButton(
            onPressed: () async {
              await NativeClipboard.clear();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clipboard cleared')),
                );
              }
            },
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear the clipboard',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _Bubble(message: _messages[index]),
                  ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: ImagePasteRegion(
                onImagePasted: _onImagePasted,
                child: TextField(
                  controller: _text,
                  contextMenuBuilder: ImagePasteRegion.contextMenuBuilder,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Message, or paste an image…',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Copy an image anywhere on the device, then paste it into the '
              'field below.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final PastedImageMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = message.image;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(image.bytes, fit: BoxFit.contain),
            ),
            if (message.caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                child: Text(
                  message.caption,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
              child: Text(
                '${image.mimeType} · ${image.lengthInBytes ~/ 1024} KB',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
