import 'dart:typed_data';

/// Shares a file using the native Web Share API. Not supported outside web.
Future<bool> shareFileOnWeb({
  required Uint8List bytes,
  required String filename,
  required String title,
  String? text,
}) async {
  throw UnsupportedError('shareFileOnWeb is only supported on the web.');
}

/// Returns true if the current web browser supports file sharing.
bool get webShareFilesSupported => false;

/// Returns true if the current platform is likely a mobile/touch device.
bool get isMobileWeb => false;
