import 'package:cloud_functions/cloud_functions.dart';
import 'package:brisconnect/config/app_config.dart';

/// Calls the generatePost Firebase Function which proxies Google Gemini API.
class AiPostService {
  static const Duration defaultTimeout = Duration(seconds: 10);

  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) _call;

  AiPostService({Future<Map<String, dynamic>> Function(Map<String, dynamic>)? call})
      : _call = call ?? _defaultCall;

  static Future<Map<String, dynamic>> _defaultCall(
    Map<String, dynamic> params,
  ) async {
    final callable = FirebaseFunctions.instanceFor(
            region: AppConfig.firebaseFunctionsRegion)
        .httpsCallable('generatePost');
    final result = await callable.call<Map<String, dynamic>>(params);
    return result.data;
  }

  Future<String> generatePost({
    required String postType,
    required String businessName,
    required String category,
    String extraContext = '',
    Duration timeout = defaultTimeout,
  }) async {
    final params = {
      'postType': postType.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim(),
      'businessName': businessName,
      'category': category,
      'extraContext': extraContext,
    };

    final data = await _call(params).timeout(
      timeout,
      onTimeout: () => throw Exception(
        'The AI service took too long to respond. Please try again.',
      ),
    );

    final post = data['post'] as String?;
    if (post == null || post.isEmpty) {
      throw Exception('No post generated. Please try again.');
    }
    return post;
  }
}
