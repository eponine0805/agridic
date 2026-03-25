import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agridic/models/post.dart';
import 'package:agridic/services/offline_queue_service.dart';

Post _makePost(String id) => Post(
      postId: id,
      userId: 'user_1',
      isOfficial: false,
      userRole: 'farmer',
      userName: 'Test User',
      content: const PostContent(textShort: 'test content'),
      timestamp: DateTime(2024, 1, 1),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('enqueue / getAll', () {
    test('starts empty', () async {
      expect(await OfflineQueueService.isEmpty(), isTrue);
      expect(await OfflineQueueService.count(), 0);
      expect(await OfflineQueueService.getAll(), isEmpty);
    });

    test('enqueue stores post in new format', () async {
      await OfflineQueueService.enqueue(_makePost('p1'));

      final items = await OfflineQueueService.getAll();
      expect(items.length, 1);
      // New format: wrapped as {'post': {...}}
      expect(items[0].containsKey('post'), isTrue);
      expect((items[0]['post'] as Map)['postId'], 'p1');
    });

    test('enqueue with localTweetImagePath stores path', () async {
      await OfflineQueueService.enqueue(
        _makePost('p2'),
        localTweetImagePath: '/storage/img.jpg',
      );

      final items = await OfflineQueueService.getAll();
      expect(items.length, 1);
      expect(items[0]['localTweetImagePath'], '/storage/img.jpg');
    });

    test('enqueue without localTweetImagePath omits the key', () async {
      await OfflineQueueService.enqueue(_makePost('p3'));
      final items = await OfflineQueueService.getAll();
      expect(items[0].containsKey('localTweetImagePath'), isFalse);
    });

    test('multiple posts are all stored in order', () async {
      await OfflineQueueService.enqueue(_makePost('a'));
      await OfflineQueueService.enqueue(_makePost('b'));
      await OfflineQueueService.enqueue(_makePost('c'));

      expect(await OfflineQueueService.count(), 3);
      final items = await OfflineQueueService.getAll();
      final ids = items
          .map((e) => (e['post'] as Map<String, dynamic>)['postId'])
          .toList();
      expect(ids, ['a', 'b', 'c']);
    });

    test('content fields are preserved through enqueue', () async {
      final post = Post(
        postId: 'full',
        userId: 'u42',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Expert',
        content: const PostContent(
          textShort: 'short',
          imageLow: 'data:low',
          imageHigh: 'https://high',
        ),
        location: (-1.0, 36.0),
        timestamp: DateTime(2024, 3, 15),
        dictTags: ['tag1', 'tag2'],
      );
      await OfflineQueueService.enqueue(post);

      final items = await OfflineQueueService.getAll();
      final postData = items[0]['post'] as Map<String, dynamic>;
      expect(postData['userId'], 'u42');
      expect(postData['isOfficial'], true);
      final content = postData['content'] as Map<String, dynamic>;
      expect(content['textShort'], 'short');
      expect(content['imageLow'], 'data:low');
      expect(postData['location'], {'lat': -1.0, 'lng': 36.0});
    });
  });

  group('clear', () {
    test('removes all items', () async {
      await OfflineQueueService.enqueue(_makePost('x'));
      await OfflineQueueService.enqueue(_makePost('y'));
      expect(await OfflineQueueService.count(), 2);

      await OfflineQueueService.clear();

      expect(await OfflineQueueService.isEmpty(), isTrue);
      expect(await OfflineQueueService.count(), 0);
    });

    test('clear on empty queue does nothing', () async {
      await OfflineQueueService.clear(); // should not throw
      expect(await OfflineQueueService.isEmpty(), isTrue);
    });

    test('can enqueue again after clear', () async {
      await OfflineQueueService.enqueue(_makePost('old'));
      await OfflineQueueService.clear();
      await OfflineQueueService.enqueue(_makePost('new'));

      expect(await OfflineQueueService.count(), 1);
      final items = await OfflineQueueService.getAll();
      expect((items[0]['post'] as Map)['postId'], 'new');
    });
  });

  group('count / isEmpty', () {
    test('count reflects queue size accurately', () async {
      expect(await OfflineQueueService.count(), 0);
      await OfflineQueueService.enqueue(_makePost('1'));
      expect(await OfflineQueueService.count(), 1);
      await OfflineQueueService.enqueue(_makePost('2'));
      expect(await OfflineQueueService.count(), 2);
      await OfflineQueueService.clear();
      expect(await OfflineQueueService.count(), 0);
    });

    test('isEmpty is true only when queue is empty', () async {
      expect(await OfflineQueueService.isEmpty(), isTrue);
      await OfflineQueueService.enqueue(_makePost('z'));
      expect(await OfflineQueueService.isEmpty(), isFalse);
    });
  });

  group('backward compatibility (old plain-postJson format)', () {
    test('old format without post wrapper is still readable', () async {
      // Old format: post.toJson() stored directly without the 'post' key wrapper
      final post = _makePost('old_1');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'offline_post_queue',
        jsonEncode([post.toJson()]),
      );

      final items = await OfflineQueueService.getAll();
      expect(items.length, 1);
      // Old format has no 'post' key — treated directly as postJson
      expect(items[0].containsKey('post'), isFalse);
      expect(items[0]['postId'], 'old_1');
    });
  });
}
