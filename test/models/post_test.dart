import 'package:flutter_test/flutter_test.dart';
import 'package:agridic/models/post.dart';

void main() {
  group('PostContent', () {
    test('fromMap with all fields', () {
      final m = {
        'textShort': 'hello',
        'textFull': 'full text',
        'textFullManual': 'manual',
        'textFullVisual': 'visual',
        'steps': ['step1', 'step2'],
        'imageLow': 'data:low',
        'imageHigh': 'https://high',
        'images': ['img1', 'img2'],
      };
      final c = PostContent.fromMap(m);
      expect(c.textShort, 'hello');
      expect(c.textFull, 'full text');
      expect(c.steps, ['step1', 'step2']);
      expect(c.imageLow, 'data:low');
      expect(c.imageHigh, 'https://high');
      expect(c.images, ['img1', 'img2']);
    });

    test('fromMap with empty map uses defaults', () {
      final c = PostContent.fromMap({});
      expect(c.textShort, '');
      expect(c.textFull, '');
      expect(c.steps, isEmpty);
      expect(c.imageLow, '');
      expect(c.imageHigh, '');
      expect(c.images, isEmpty);
    });

    test('toMap roundtrip', () {
      const c = PostContent(
        textShort: 'short',
        textFull: 'full',
        steps: ['a', 'b'],
        imageLow: 'low',
        imageHigh: 'high',
        images: ['x', 'y'],
      );
      final m = c.toMap();
      final c2 = PostContent.fromMap(m);
      expect(c2.textShort, c.textShort);
      expect(c2.textFull, c.textFull);
      expect(c2.steps, c.steps);
      expect(c2.imageLow, c.imageLow);
      expect(c2.imageHigh, c.imageHigh);
      expect(c2.images, c.images);
    });
  });

  group('Post.fromMap', () {
    Map<String, dynamic> baseMap() => {
          'postId': 'post_001',
          'userId': 'user_abc',
          'isOfficial': false,
          'userRole': 'farmer',
          'userName': 'Taro',
          'content': {'textShort': 'test post'},
          'timestamp': '2024-01-15T10:30:00.000Z',
          'isVerified': false,
          'reports': 0,
          'isHidden': false,
          'likes': 5,
          'likedBy': ['u1', 'u2'],
          'distanceKm': 3.5,
          'viewMode': 'text',
          'dictCrop': 'Maize',
          'dictCategory': 'Pests',
          'dictTags': ['pest', 'borer'],
          'inDictionary': true,
        };

    test('parses all fields correctly', () {
      final post = Post.fromMap(baseMap());
      expect(post.postId, 'post_001');
      expect(post.userId, 'user_abc');
      expect(post.isOfficial, false);
      expect(post.userRole, 'farmer');
      expect(post.userName, 'Taro');
      expect(post.content.textShort, 'test post');
      expect(post.timestamp, DateTime.utc(2024, 1, 15, 10, 30, 0));
      expect(post.likes, 5);
      expect(post.likedBy, ['u1', 'u2']);
      expect(post.distanceKm, 3.5);
      expect(post.dictCrop, 'Maize');
      expect(post.dictTags, ['pest', 'borer']);
      expect(post.inDictionary, true);
    });

    test('parses location when present', () {
      final m = baseMap()..['location'] = {'lat': -1.234, 'lng': 36.789};
      final post = Post.fromMap(m);
      expect(post.location, isNotNull);
      expect(post.location!.$1, closeTo(-1.234, 0.001));
      expect(post.location!.$2, closeTo(36.789, 0.001));
    });

    test('location is null when location field absent', () {
      final post = Post.fromMap(baseMap());
      expect(post.location, isNull);
    });

    test('location is null when lat is null', () {
      final m = baseMap()..['location'] = {'lat': null, 'lng': 36.789};
      final post = Post.fromMap(m);
      expect(post.location, isNull);
    });

    test('location is null when lng is null', () {
      final m = baseMap()..['location'] = {'lat': -1.234, 'lng': null};
      final post = Post.fromMap(m);
      expect(post.location, isNull);
    });

    test('uses defaults for missing optional fields', () {
      final post = Post.fromMap({'postId': 'x', 'isOfficial': false, 'userRole': 'farmer', 'userName': 'Y'});
      expect(post.userId, '');
      expect(post.likes, 0);
      expect(post.likedBy, isEmpty);
      expect(post.reports, 0);
      expect(post.isHidden, false);
      expect(post.distanceKm, 0.0);
      expect(post.viewMode, 'text');
      expect(post.dictCrop, '');
      expect(post.dictTags, isEmpty);
      expect(post.inDictionary, false);
      expect(post.timestamp, isNull);
    });

    test('invalid timestamp string gives null timestamp', () {
      final m = baseMap()..['timestamp'] = 'not-a-date';
      final post = Post.fromMap(m);
      expect(post.timestamp, isNull);
    });

    test('supports old format with id instead of postId', () {
      final m = baseMap();
      m.remove('postId');
      m['id'] = 'old_id_format';
      final post = Post.fromMap(m);
      expect(post.postId, 'old_id_format');
    });
  });

  group('Post.toJson / fromMap roundtrip', () {
    test('roundtrip preserves all fields', () {
      final original = Post(
        postId: 'p1',
        userId: 'u1',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Dr. Smith',
        content: const PostContent(
          textShort: 'short',
          textFull: 'long',
          steps: ['do this', 'do that'],
          imageLow: 'data:low',
          imageHigh: 'https://high',
          images: ['a', 'b'],
        ),
        location: (-1.0, 36.0),
        timestamp: DateTime(2024, 6, 1, 12, 0, 0),
        isVerified: true,
        reports: 2,
        isHidden: false,
        likes: 10,
        likedBy: ['x', 'y'],
        distanceKm: 5.5,
        viewMode: 'manual',
        dictCrop: 'Tomato',
        dictCategory: 'Disease',
        dictTags: ['blight', 'fungus'],
        inDictionary: true,
      );

      final json = original.toJson();
      final restored = Post.fromMap(json);

      expect(restored.postId, original.postId);
      expect(restored.userId, original.userId);
      expect(restored.isOfficial, original.isOfficial);
      expect(restored.userRole, original.userRole);
      expect(restored.userName, original.userName);
      expect(restored.content.textShort, original.content.textShort);
      expect(restored.content.textFull, original.content.textFull);
      expect(restored.content.steps, original.content.steps);
      expect(restored.content.imageLow, original.content.imageLow);
      expect(restored.content.imageHigh, original.content.imageHigh);
      expect(restored.content.images, original.content.images);
      expect(restored.location, original.location);
      expect(restored.timestamp, original.timestamp);
      expect(restored.isVerified, original.isVerified);
      expect(restored.reports, original.reports);
      expect(restored.likes, original.likes);
      expect(restored.likedBy, original.likedBy);
      expect(restored.distanceKm, original.distanceKm);
      expect(restored.viewMode, original.viewMode);
      expect(restored.dictCrop, original.dictCrop);
      expect(restored.dictTags, original.dictTags);
      expect(restored.inDictionary, original.inDictionary);
    });

    test('roundtrip with null location', () {
      final post = Post(
        postId: 'p2',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Jane',
        content: const PostContent(textShort: 'no location'),
      );
      final restored = Post.fromMap(post.toJson());
      expect(restored.location, isNull);
    });
  });
}
