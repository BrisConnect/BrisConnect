import 'dart:typed_data';

class ProfileImageUtils {
  static const int maxImageBytes = 700 * 1024;

  static bool isLikelyJpeg(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
  }

  static bool isLikelyPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A;
  }

  static bool isSupportedImage(Uint8List bytes) {
    return isLikelyJpeg(bytes) || isLikelyPng(bytes);
  }
}
