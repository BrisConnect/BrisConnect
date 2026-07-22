import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/ai_post_service.dart';

void main() {
  group('AiPostService', () {
    test('returns generated post on successful callable response', () async {
      Future<Map<String, dynamic>> call(Map<String, dynamic> params) async =>
          {'post': 'Hello Brisbane! #food'};
      final service = AiPostService(call: call);

      final result = await service.generatePost(
        postType: 'Promotion',
        businessName: 'Test Cafe',
        category: 'Cafe',
        extraContext: '20% off',
      );

      expect(result, 'Hello Brisbane! #food');
    });

    test('throws when response post is empty', () async {
      Future<Map<String, dynamic>> call(Map<String, dynamic> params) async =>
          {'post': ''};
      final service = AiPostService(call: call);

      expect(
        () => service.generatePost(
          postType: 'Promotion',
          businessName: 'Test Cafe',
          category: 'Cafe',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No post generated'),
        )),
      );
    });

    test('throws when response post is missing', () async {
      Future<Map<String, dynamic>> call(Map<String, dynamic> params) async =>
          {'other': 'value'};
      final service = AiPostService(call: call);

      expect(
        () => service.generatePost(
          postType: 'Promotion',
          businessName: 'Test Cafe',
          category: 'Cafe',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No post generated'),
        )),
      );
    });

    test('throws timeout message when callable exceeds timeout', () async {
      Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
        await Future.delayed(const Duration(seconds: 1));
        return {'post': 'late'};
      }

      final service = AiPostService(call: call);

      expect(
        () => service.generatePost(
          postType: 'Promotion',
          businessName: 'Test Cafe',
          category: 'Cafe',
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('took too long'),
        )),
      );
    });

    test('strips non-ASCII characters from postType', () async {
      Map<String, dynamic>? captured;
      Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
        captured = params;
        return {'post': 'ok'};
      }

      final service = AiPostService(call: call);
      await service.generatePost(
        postType: '🎉 Promotion',
        businessName: 'Test Cafe',
        category: 'Cafe',
      );

      expect(captured?['postType'], 'Promotion');
    });
  });
}
