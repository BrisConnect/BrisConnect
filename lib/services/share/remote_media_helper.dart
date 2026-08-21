import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Shared helper for downloading remote media to a temporary file.
///
/// Preserves the behaviour previously duplicated across story sharing
/// services: HTTP GET, optional timeout, extension extraction, temp file
/// write, and silent failure (returns `null` on any error).
class RemoteMediaHelper {
  RemoteMediaHelper._();

  /// Downloads the resource at [url] and writes it to a temporary file.
  ///
  /// [client] is optional; a new [http.Client] is created if omitted.
  /// [timeout] is optional; if provided the request will time out after
  /// the given duration.
  /// [fileNamePrefix] is prepended to the generated temp file name.
  static Future<File?> downloadRemoteMedia(
    String url, {
    http.Client? client,
    Duration? timeout,
    String fileNamePrefix = 'brisconnect_remote',
  }) async {
    try {
      final request = (client ?? http.Client()).get(Uri.parse(url));
      final response =
          timeout != null ? await request.timeout(timeout) : await request;
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }

      final ext = _extensionFromUrl(url);
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static String _extensionFromUrl(String url) {
    final ext = url.split('.').lastOrNull?.toLowerCase() ?? '';
    if (ext.isNotEmpty && ext.length <= 5) return ext;
    return 'jpg';
  }
}
