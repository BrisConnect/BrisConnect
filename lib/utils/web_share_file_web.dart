// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unused_import, uri_does_not_exist

import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// Returns true if the current web browser supports file sharing.
bool get webShareFilesSupported {
  try {
    final navigator = html.window.navigator;
    final canShare = js_util.getProperty(navigator, 'canShare');
    if (canShare == null) return false;

    // Construct a dummy file to test shareability.
    final dummyBlob = html.Blob(['test'], 'image/png');
    final file = _createHtmlFile(dummyBlob, 'test.png', 'image/png');
    final testData = js_util.jsify({'files': [file]});
    final boundCanShare = js_util.callMethod(canShare, 'bind', [navigator]);
    return js_util.callMethod(boundCanShare, 'call', [navigator, testData])
        as bool;
  } catch (_) {
    return false;
  }
}

/// Returns true if the current platform is likely a mobile/touch device.
bool get isMobileWeb {
  try {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    return RegExp(r'android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini')
        .hasMatch(userAgent);
  } catch (_) {
    return false;
  }
}

/// Shares a file using the native Web Share API.
///
/// Returns true if the share was triggered, or false if the browser does not
/// support it. Throws on actual share failures.
Future<bool> shareFileOnWeb({
  required Uint8List bytes,
  required String filename,
  required String title,
  String? text,
}) async {
  final navigator = html.window.navigator;
  final share = js_util.getProperty(navigator, 'share');
  if (share == null) return false;

  final blob = html.Blob([bytes], 'image/png');
  final file = _createHtmlFile(blob, filename, 'image/png');

  final data = js_util.jsify({
    'title': title,
    if (text != null && text.isNotEmpty) 'text': text,
    'files': [file],
  });

  await js_util.promiseToFuture(
    js_util.callMethod(share, 'bind', [navigator])(data),
  );
  return true;
}

Object _createHtmlFile(html.Blob blob, String filename, String type) {
  final fileConstructor = js_util.getProperty(html.window, 'File') as Function;
  return js_util.callConstructor(
    fileConstructor,
    [
      js_util.jsify([blob]),
      filename,
      js_util.jsify({'type': type}),
    ],
  );
}
