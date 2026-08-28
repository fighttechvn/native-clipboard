## 0.2.0

* **The selection menu is the platform's own again.** `contextMenuBuilder`
  always drew a Flutter toolbar, so on iOS 16 and up a field showed one over
  the system menu UIKit draws — two menus, each with its own *Copy*. It now
  builds what the field would have built for itself: the system menu on iOS,
  Flutter's toolbar everywhere else, and neither is touched at all when the
  clipboard holds no image.
* On the iOS system menu, an image on the clipboard replaces *Paste* with one
  that pastes it. Without an image the platform's own *Paste* is left alone,
  which is what pastes text without raising the *Allow Paste?* banner.
* A *Paste* the plugin puts back now goes straight after *Cut* and *Copy*,
  where every one of these menus puts it. It used to be appended last, which
  on iOS is behind the overflow arrow — there, but invisible.
* Needs Flutter 3.38 for `IOSSystemContextMenuItemCustom`.

## 0.1.1

* `showClipboardImageSheet` and `ClipboardImageSheet` take
  `sendButtonBackgroundColor` and `sendButtonForegroundColor`, so an app whose
  brand colour is not in its `ColorScheme` states what the send button is
  painted with instead of leaving the sheet to infer it. Left out, they fall
  back to `colorScheme.primary` / `onPrimary` as before.

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
