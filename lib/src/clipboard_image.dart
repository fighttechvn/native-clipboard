import 'package:flutter/foundation.dart';

/// An image read off the system clipboard.
///
/// [bytes] are the encoded file, not raw pixels: they can be handed straight
/// to `Image.memory`, written to disk, or posted as a multipart upload. The
/// platform hands back what was on the clipboard whenever it can read it, so a
/// screenshot copied as a PNG stays a PNG and keeps its transparency; only an
/// image that has to be re-encoded to be read at all comes back as JPEG.
@immutable
class ClipboardImage {
  /// The encoded image.
  final Uint8List bytes;

  /// What [bytes] are encoded as — `image/png`, `image/jpeg`, `image/gif`,
  /// `image/heic`. Never empty: an image whose type the platform will not name
  /// is reported as `application/octet-stream`.
  final String mimeType;

  /// Pixel size, when the platform could read it without decoding the whole
  /// image. Null is normal and says nothing about whether [bytes] are valid.
  final int? width;
  final int? height;

  const ClipboardImage({
    required this.bytes,
    required this.mimeType,
    this.width,
    this.height,
  });

  /// The extension a file holding [bytes] should carry, without the dot.
  ///
  /// Falls back to `bin` rather than guessing `jpg`: a name that lies about
  /// its contents is worse than one that admits it does not know.
  String get fileExtension => switch (mimeType) {
    'image/png' => 'png',
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/heic' || 'image/heif' => 'heic',
    'image/bmp' => 'bmp',
    'image/tiff' => 'tiff',
    _ => 'bin',
  };

  /// How large the image is, in bytes.
  int get lengthInBytes => bytes.lengthInBytes;

  static ClipboardImage? fromMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final bytes = value['bytes'];
    if (bytes is! Uint8List || bytes.isEmpty) {
      return null;
    }

    final mimeType = value['mimeType'];
    final width = value['width'];
    final height = value['height'];

    return ClipboardImage(
      bytes: bytes,
      mimeType: mimeType is String && mimeType.isNotEmpty
          ? mimeType
          : 'application/octet-stream',
      width: width is int ? width : null,
      height: height is int ? height : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardImage &&
          other.mimeType == mimeType &&
          other.width == width &&
          other.height == height &&
          listEquals(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(mimeType, width, height, bytes.lengthInBytes);

  @override
  String toString() =>
      'ClipboardImage($mimeType, ${width ?? '?'}x${height ?? '?'}, '
      '$lengthInBytes bytes)';
}
