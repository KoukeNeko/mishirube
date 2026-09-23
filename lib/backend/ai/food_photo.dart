import 'dart:convert';
import 'dart:typed_data';

/// A food photo as a provider receives it: the image's bytes and their
/// media type, and the file they came from, which Apple's on-device
/// model reads itself.
class FoodPhoto {
  const FoodPhoto({
    required this.path,
    required this.bytes,
    required this.mimeType,
  });

  final String path;
  final Uint8List bytes;

  /// `image/jpeg`, `image/png` or `image/webp`.
  final String mimeType;

  String get base64 => base64Encode(bytes);

  /// `data:image/jpeg;base64,…`, as OpenAI-shaped APIs take an image.
  String get dataUrl => 'data:$mimeType;base64,$base64';
}

/// The media type of an image from its first bytes, or null for a format
/// not every provider reads (HEIC among them).
String? imageMimeType(Uint8List bytes) {
  bool startsWith(List<int> magic, [int offset = 0]) =>
      bytes.length >= offset + magic.length &&
      [for (var i = 0; i < magic.length; i++) bytes[offset + i] == magic[i]]
          .every((same) => same);
  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  // RIFF....WEBP
  if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
      startsWith(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}

/// JPEG markers whose segments say where and how a photo was taken, not
/// what is in it: EXIF and XMP (APP1, with the GPS position, time and
/// device), IPTC (APP13) and comments. The colour profile (APP2) and the
/// decoder's own segments stay, so the picture is unchanged.
const _metadataMarkers = {0xE1, 0xED, 0xFE};

/// [jpeg] without its metadata segments, or unchanged when it is not a
/// JPEG this can walk. The image data itself is copied as it is.
Uint8List stripJpegMetadata(Uint8List jpeg) {
  if (imageMimeType(jpeg) != 'image/jpeg') return jpeg;
  final out = BytesBuilder(copy: false)..add(jpeg.sublist(0, 2));
  var i = 2;
  while (i + 4 <= jpeg.length) {
    if (jpeg[i] != 0xFF) return jpeg;
    final marker = jpeg[i + 1];
    // Start of scan: what follows is the image itself, to the end.
    if (marker == 0xDA) {
      out.add(jpeg.sublist(i));
      return out.takeBytes();
    }
    final length = (jpeg[i + 2] << 8) | jpeg[i + 3];
    final end = i + 2 + length;
    if (length < 2 || end > jpeg.length) return jpeg;
    if (!_metadataMarkers.contains(marker)) out.add(jpeg.sublist(i, end));
    i = end;
  }
  return jpeg;
}
