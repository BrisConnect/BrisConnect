import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/share/business_share_service.dart';

void main() {
  group('BusinessShareService', () {
    late BusinessShareService shareService;
    final List<String> clipboardHistory = [];

    setUp(() {
      clipboardHistory.clear();
      shareService = BusinessShareService(
        clipboardWriter: (text) async => clipboardHistory.add(text),
      );
    });

    test('buildBusinessUrl creates correct deep link', () {
      final url = shareService.buildBusinessUrl('biz_123', 'Café Brisbane');
      expect(
        url,
        'https://www.brisconnect.com.au/business/biz_123?name=${Uri.encodeComponent('Café Brisbane')}',
      );
    });

    test('platformLabel returns correct labels', () {
      expect(shareService.platformLabel('facebook'), 'Facebook');
      expect(shareService.platformLabel('instagram'), 'Instagram');
      expect(shareService.platformLabel('tiktok'), 'TikTok');
      expect(shareService.platformLabel('native'), 'another app');
      expect(shareService.platformLabel('unknown'), 'unknown');
    });

    test('shareToPlatform returns copied for Instagram', () async {
      final result = await shareService.shareToPlatform(
        platform: 'instagram',
        businessId: 'biz_123',
        businessName: 'Test Cafe',
      );
      expect(result, ShareResult.copied);
    });

    test('shareToPlatform returns copied for TikTok', () async {
      final result = await shareService.shareToPlatform(
        platform: 'tiktok',
        businessId: 'biz_123',
        businessName: 'Test Cafe',
      );
      expect(result, ShareResult.copied);
    });

    test('shareToPlatform returns copied for copy action', () async {
      final result = await shareService.shareToPlatform(
        platform: 'copy',
        businessId: 'biz_123',
        businessName: 'Test Cafe',
      );
      expect(result, ShareResult.copied);
    });

    test('shareToPlatform returns copied for unknown platform as fallback',
        () async {
      final result = await shareService.shareToPlatform(
        platform: 'twitter',
        businessId: 'biz_123',
        businessName: 'Test Cafe',
      );
      expect(result, ShareResult.copied);
    });

    test('shareToPlatform completes within 2 seconds for copy action',
        () async {
      final stopwatch = Stopwatch()..start();
      await shareService.shareToPlatform(
        platform: 'copy',
        businessId: 'biz_123',
        businessName: 'Test Cafe',
      );
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    });
  });
}
