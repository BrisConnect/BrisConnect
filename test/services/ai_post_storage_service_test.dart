import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brisconnect/models/ai_generated_post.dart';
import 'package:brisconnect/services/ai_post_storage_service.dart';

void main() {
  group('AiPostStorageService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AiPostStorageService service;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      service = AiPostStorageService(firestore: fakeFirestore);
    });

    AiGeneratedPost samplePost({AiPostStatus status = AiPostStatus.draft}) {
      return AiGeneratedPost(
        businessId: 'b1',
        ownerId: 'owner@test.com',
        postType: AiPostType.promotion,
        title: 'Midweek Special',
        description: 'Great deal',
        price: r'$20',
        discount: '20% off',
        generatedContent: 'Enjoy 20% off! #brisbane',
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    test('saveDraft stores post with draft status', () async {
      final id = await service.saveDraft(samplePost());
      expect(id, isNotEmpty);

      final saved = await service.getPost(id);
      expect(saved, isNotNull);
      expect(saved!.status, AiPostStatus.draft);
      expect(saved.title, 'Midweek Special');
    });

    test('publish stores post with published status', () async {
      final id = await service.publish(samplePost());
      expect(id, isNotEmpty);

      final saved = await service.getPost(id);
      expect(saved, isNotNull);
      expect(saved!.status, AiPostStatus.published);
    });

    test('getPostsForOwner returns posts ordered by updatedAt desc', () async {
      final post1 = samplePost();
      await Future.delayed(const Duration(milliseconds: 10));
      final post2 = samplePost()
          .copyWith(title: 'Second', updatedAt: DateTime.now());

      await service.saveDraft(post1);
      await service.saveDraft(post2);

      final posts = await service.getPostsForOwner('owner@test.com').first;
      expect(posts.length, 2);
      expect(posts.first.title, 'Second');
    });

    test('deletePost removes the post', () async {
      final id = await service.saveDraft(samplePost());
      await service.deletePost(id);

      final deleted = await service.getPost(id);
      expect(deleted, isNull);
    });
  });
}
