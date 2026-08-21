import 'dart:typed_data';

/// Downloads an image on unsupported platforms.
///
/// The conditional export in [image_download.dart] replaces this with the
/// web implementation when compiling for the web.
Future<void> downloadImage(Uint8List bytes, String filename) async {
  throw UnsupportedError(
    'downloadImage is only supported on the web. '
    'Use the platform gallery saver on mobile/desktop.',
  );
}
