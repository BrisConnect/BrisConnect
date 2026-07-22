import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/services/share/content_share_service.dart';

void main() {
  group('ContentShareService', () {
    late ContentShareService shareService;
    final List<String> clipboardHistory = [];

    setUp(() {
      clipboardHistory.clear();
      shareService = ContentShareService(
        clipboardWriter: (text) async => clipboardHistory.add(text),
      );
    });

    group('buildShareUrl', () {
      test('creates business deep link', () {
        final url = shareService.buildShareUrl(
          type: ShareContentType.business,
          id: 'biz_123',
          slug: 'Café Brisbane',
        );
        expect(
          url,
          'https://www.brisconnect.com.au/business/biz_123?name=${Uri.encodeComponent('Café Brisbane')}',
        );
      });

      test('creates event deep link', () {
        final url = shareService.buildShareUrl(
          type: ShareContentType.event,
          id: 'evt_456',
          slug: 'Night Market',
        );
        expect(
          url,
          'https://www.brisconnect.com.au/event/evt_456?name=${Uri.encodeComponent('Night Market')}',
        );
      });

      test('creates food deep link', () {
        final url = shareService.buildShareUrl(
          type: ShareContentType.food,
          id: 'food_789',
          slug: 'Best Tacos',
        );
        expect(
          url,
          'https://www.brisconnect.com.au/food/food_789?name=${Uri.encodeComponent('Best Tacos')}',
        );
      });

      test('creates stadium/venue deep link', () {
        final url = shareService.buildShareUrl(
          type: ShareContentType.stadium,
          id: 'venue_000',
          slug: 'Suncorp Stadium',
        );
        expect(
          url,
          'https://www.brisconnect.com.au/venue/venue_000?name=${Uri.encodeComponent('Suncorp Stadium')}',
        );
      });

      test('omits slug query param when slug is empty', () {
        final url = shareService.buildShareUrl(
          type: ShareContentType.event,
          id: 'evt_456',
        );
        expect(url, 'https://www.brisconnect.com.au/event/evt_456');
      });
    });

    group('platformLabel', () {
      test('returns correct labels', () {
        expect(shareService.platformLabel('facebook'), 'Facebook');
        expect(shareService.platformLabel('instagram'), 'Instagram');
        expect(shareService.platformLabel('tiktok'), 'TikTok');
        expect(shareService.platformLabel('native'), 'another app');
        expect(shareService.platformLabel('copy'), 'clipboard');
        expect(shareService.platformLabel('unknown'), 'unknown');
      });
    });

    group('buildShareText', () {
      test('includes all provided fields', () {
        final text = shareService.buildShareText(
          title: 'Night Market',
          url: 'https://example.com/event/1',
          description: 'Great food and music.',
          location: 'South Bank',
          dateTime: 'Sat 7pm',
        );
        expect(
          text,
          'Night Market\n\nSat 7pm\n\nSouth Bank\n\nGreat food and music.\n\nhttps://example.com/event/1',
        );
      });

      test('skips empty optional fields', () {
        final text = shareService.buildShareText(
          title: 'Night Market',
          url: 'https://example.com/event/1',
        );
        expect(text, 'Night Market\n\nhttps://example.com/event/1');
      });
    });

    group('shareToPlatform', () {
      test('returns copied for Instagram', () async {
        final result = await shareService.shareToPlatform(
          platform: 'instagram',
          type: ShareContentType.event,
          id: 'evt_123',
          title: 'Test Event',
        );
        expect(result, ShareResult.copied);
        expect(clipboardHistory, isNotEmpty);
      });

      test('returns copied for TikTok', () async {
        final result = await shareService.shareToPlatform(
          platform: 'tiktok',
          type: ShareContentType.event,
          id: 'evt_123',
          title: 'Test Event',
        );
        expect(result, ShareResult.copied);
      });

      test('returns copied for copy action', () async {
        final result = await shareService.shareToPlatform(
          platform: 'copy',
          type: ShareContentType.event,
          id: 'evt_123',
          title: 'Test Event',
          description: 'A fun event.',
          location: 'City',
          dateTime: 'Tomorrow',
        );
        expect(result, ShareResult.copied);
        expect(clipboardHistory.last, contains('A fun event.'));
        expect(clipboardHistory.last, contains('City'));
        expect(clipboardHistory.last, contains('Tomorrow'));
      });

      test('returns copied for unknown platform as fallback', () async {
        final result = await shareService.shareToPlatform(
          platform: 'twitter',
          type: ShareContentType.business,
          id: 'biz_123',
          title: 'Test Cafe',
        );
        expect(result, ShareResult.copied);
      });

      test('clipboard text contains canonical URL', () async {
        await shareService.shareToPlatform(
          platform: 'copy',
          type: ShareContentType.food,
          id: 'food_123',
          title: 'Test Food',
        );
        expect(
          clipboardHistory.last,
          contains('https://www.brisconnect.com.au/food/food_123'),
        );
      });

      test('completes within 2 seconds for copy action', () async {
        final stopwatch = Stopwatch()..start();
        await shareService.shareToPlatform(
          platform: 'copy',
          type: ShareContentType.event,
          id: 'evt_123',
          title: 'Test Event',
        );
        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      });

      test('falls back to copied on timeout', () async {
        final slowClipboardHistory = <String>[];
        final slowService = ContentShareService(
          clipboardWriter: (text) async {
            await Future.delayed(const Duration(milliseconds: 2100));
            slowClipboardHistory.add(text);
          },
        );
        final result = await slowService.shareToPlatform(
          platform: 'copy',
          type: ShareContentType.event,
          id: 'evt_123',
          title: 'Test Event',
        );
        expect(result, ShareResult.timedOut);
        expect(slowClipboardHistory, isNotEmpty);
      });
    });
  });
}
