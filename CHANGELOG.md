## 0.1.0

First release.

* `NativeClipboard` — `hasImage`, `getImage`, `getImages`, `copyImage`,
  `clear`, and `getText` / `setText` passed straight to Flutter's own
  `Clipboard`.
* `ImagePasteRegion` — a text field the user can paste an image into, by
  keyboard and from the selection toolbar, with every other clipboard action
  left as it was.
* `showClipboardImageSheet` — the pasted image in a bottom sheet with a
  caption field and a send button, so nothing is sent on one keystroke.
* Android: reads the clip's bytes as they are, so a copied PNG keeps its
  transparency; falls back to decoding and re-encoding as JPEG. Copying out
  goes through a `FileProvider` the plugin declares itself.
* iOS: reads every item of the pasteboard, picking the best representation of
  each; `hasImage` answers without raising the paste banner.
