import 'package:cloud_functions/cloud_functions.dart';
import 'package:brisconnect/config/app_config.dart';

/// Calls the generatePost Firebase Function which proxies Google Gemini API.
class AiPostService {
  static Future<String> generatePost({
    required String postType,
    required String businessName,
    required String category,
    String extraContext = '',
  }) async {
    final callable = FirebaseFunctions.instanceFor(
            region: AppConfig.firebaseFunctionsRegion)
        .httpsCallable('generatePost');

    final result = await callable.call<Map<String, dynamic>>({
      'postType': postType.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim(),
      'businessName': businessName,
      'category': category,
      'extraContext': extraContext,
    });

    final post = result.data['post'] as String?;
    if (post == null || post.isEmpty) {
      throw Exception('No post generated. Please try again.');
    }
    return post;
  }
}
