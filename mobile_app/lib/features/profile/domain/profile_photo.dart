import 'dart:typed_data';

abstract final class ProfilePhotoPolicy {
  static const maximumBytes = 5 * 1024 * 1024;
  static const allowedContentTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  static String? detectContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static void validate(Uint8List bytes, String contentType) {
    if (bytes.isEmpty || bytes.length > maximumBytes) {
      throw ArgumentError.value(bytes.length, 'bytes');
    }
    if (!allowedContentTypes.contains(contentType) ||
        detectContentType(bytes) != contentType) {
      throw ArgumentError.value(contentType, 'contentType');
    }
  }
}
