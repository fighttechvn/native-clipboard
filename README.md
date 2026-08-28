# native_clipboard

Images on and off the system clipboard, and a text field the user can paste one
into.

Flutter's `Clipboard` carries text and nothing else. A screenshot, an image
copied out of a browser, a photo shared from another app — the system is
holding all of them, and a Flutter app cannot see any of them. Pressing
`Cmd+V` over a `TextField` does nothing at all.

This plugin reads that image, and gives a text field somewhere to put it. What
the field already does is untouched: copy, cut, select all, and pasting text
stay exactly the ones Flutter installed.

## Pasting into a text field

```dart
ClipboardImage? _attachment;

ImagePasteRegion(
  onImagePasted: (image) => setState(() => _attachment = image),
  child: TextField(
    contextMenuBuilder: ImagePasteRegion.contextMenuBuilder,
  ),
)
```

That is the whole integration. `Cmd+V` / `Ctrl+V` over the field now calls
`onImagePasted` when the clipboard holds an image, and pastes text as before
when it does not. The app decides what a pasted image means — usually a
thumbnail above the composer, with a remove button.

`contextMenuBuilder` is what puts *Paste* in the selection toolbar. It is
separate because the toolbar builds its own buttons and never goes through
`Actions`, and it is worth passing: with an image on the clipboard and no text,
Flutter shows no paste button at all. The buttons stay the field's own, in the
field's own order, with the platform's own look.

Set `enabled: false` to send every paste back down the plain-text path — for a
composer that has run out of room for attachments — without taking the widget
apart.

## Sending it with a message

A paste is one keystroke, and the wrong screenshot is embarrassing — so show
the user what they are about to send. `showClipboardImageSheet` is the sheet
every chat app has: the image, a caption field, and a send button.

```dart
ImagePasteRegion(
  onImagePasted: (image) async {
    final message = await showClipboardImageSheet(context, image: image);
    if (message == null) {
      return; // Closed the sheet — nothing is sent.
    }

    await api.sendPhoto(message.image.bytes, caption: message.caption);
  },
  child: TextField(contextMenuBuilder: ImagePasteRegion.contextMenuBuilder),
)
```

It resolves to a `PastedImageMessage` — the image, and the caption trimmed —
or to null when the user closes or swipes it away. `title`, `previewLabel` and
`captionHint` take the app's own wording, and `ClipboardImageSheet` is public
for putting the same thing somewhere other than a modal sheet.

## The clipboard directly

```dart
if (await NativeClipboard.hasImage()) {
  final image = await NativeClipboard.getImage();
  // image.bytes are the encoded file: Image.memory, a File, a multipart upload.
}

await NativeClipboard.copyImage(pngBytes, mimeType: 'image/png');
await NativeClipboard.clear();
```

| | |
| --- | --- |
| `hasImage()` | Whether an image is there. On iOS this does **not** raise the paste banner, so it is the one to call before showing a button. |
| `getImage()` | The first image, or null. |
| `getImages()` | Every image; only iOS ever returns more than one. |
| `copyImage(bytes, mimeType:)` | Puts an encoded image on the clipboard. |
| `clear()` | Empties it, images and text alike. |
| `getText()` / `setText()` | Flutter's own `Clipboard`, passed straight through. |

`ClipboardImage.bytes` is the encoded file, not raw pixels. Whenever the
platform can hand over what was actually on the clipboard it does, so a copied
PNG stays a PNG and keeps its transparency; only an image that has to be
decoded to be read at all comes back as JPEG. `mimeType` says which it is, and
`fileExtension` gives the extension to save it under.

## Platform notes

**Android.** Reading the clipboard needs window focus from Android 10 on, so a
read from the background comes back empty — call it from something the user
did. Copying out writes the image to the app's cache and shares it through a
`FileProvider` the plugin declares itself, under the authority
`${applicationId}.native_clipboard.fileprovider`; nothing needs adding to the
app's manifest.

**iOS.** From iOS 16, reading a clipboard the user did not explicitly paste
shows the "Pasted from …" banner. `hasImage()` is built not to trigger it, so
check that first and read only when the user actually pasted. Reading on a
timer is what the banner exists to expose.

**Everywhere else.** Web and desktop have no implementation here and report an
empty clipboard rather than throwing, so `Ctrl+V` in a text field pastes text
exactly as it always did.

## Requirements

Android `minSdk` 21, iOS 13.

## License

MIT — see [LICENSE](LICENSE).
