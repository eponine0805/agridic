import 'package:flutter_test/flutter_test.dart';
import 'package:agridic/models/post.dart';

// AppState cannot be instantiated in unit tests because its constructor
// immediately calls Firebase / Geolocator / Connectivity APIs.
// These tests verify the core filtering and formatting logic in isolation
// using standalone functions that mirror AppState's implementation.

String _formatTime(DateTime? ts) {
  if (ts == null) return '';
  final delta = DateTime.now().difference(ts);
  final seconds = delta.inSeconds;
  if (seconds < 60) return 'now';
  if (seconds < 3600) return '${delta.inMinutes}m';
  if (seconds < 86400) return '${delta.inHours}h';
  return '${delta.inDays}d';
}

Post _makePost({
  String id = 'p1',
  String crop = '',
  String category = '',
  bool isOfficial = false,
  int likes = 0,
  double distanceKm = 0,
  DateTime? timestamp,
  bool isHidden = false,
}) =>
    Post(
      postId: id,
      isOfficial: isOfficial,
      userRole: 'farmer',
      userName: 'Test',
      content: const PostContent(textShort: 'test'),
      dictCrop: crop,
      dictCategory: category,
      likes: likes,
      distanceKm: distanceKm,
      timestamp: timestamp,
      isHidden: isHidden,
    );

List<Post> _filteredPosts(
  List<Post> posts, {
  String crop = '',
  String type = 'all',
  String sort = 'newest',
  String category = '',
}) {
  var result = posts.where((p) => !p.isHidden).toList();

  if (crop.isNotEmpty) {
    result = result.where((p) => p.dictCrop == crop).toList();
  }
  if (category.isNotEmpty) {
    result = result.where((p) => p.dictCategory == category).toList();
  }
  if (type == 'official') {
    result = result.where((p) => p.isOfficial).toList();
  } else if (type == 'community') {
    result = result.where((p) => !p.isOfficial).toList();
  }

  switch (sort) {
    case 'likes':
      result.sort((a, b) => b.likes.compareTo(a.likes));
    case 'distance':
      result.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    default:
      result.sort((a, b) =>
          (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
  }
  return result;
}

void main() {
  group('formatTime', () {
    test('returns empty string for null timestamp', () {
      expect(_formatTime(null), '');
    });

    test('returns "now" for timestamps within the last minute', () {
      final ts = DateTime.now().subtract(const Duration(seconds: 30));
      expect(_formatTime(ts), 'now');
    });

    test('returns minutes for timestamps within the last hour', () {
      final ts = DateTime.now().subtract(const Duration(minutes: 15));
      final result = _formatTime(ts);
      expect(result, endsWith('m'));
      final mins = int.parse(result.replaceAll('m', ''));
      expect(mins, closeTo(15, 1));
    });

    test('returns hours for timestamps within the last day', () {
      final ts = DateTime.now().subtract(const Duration(hours: 3));
      final result = _formatTime(ts);
      expect(result, endsWith('h'));
      final hrs = int.parse(result.replaceAll('h', ''));
      expect(hrs, closeTo(3, 1));
    });

    test('returns days for timestamps older than one day', () {
      final ts = DateTime.now().subtract(const Duration(days: 5));
      final result = _formatTime(ts);
      expect(result, endsWith('d'));
      final days = int.parse(result.replaceAll('d', ''));
      expect(days, closeTo(5, 1));
    });
  });

  group('filteredPosts — crop filter', () {
    final posts = [
      _makePost(id: 'a', crop: 'Maize'),
      _makePost(id: 'b', crop: 'Tomato'),
      _makePost(id: 'c', crop: 'Maize'),
    ];

    test('no crop filter returns all visible posts', () {
      expect(_filteredPosts(posts).length, 3);
    });

    test('crop filter returns only matching posts', () {
      final result = _filteredPosts(posts, crop: 'Maize');
      expect(result.length, 2);
      expect(result.every((p) => p.dictCrop == 'Maize'), isTrue);
    });

    test('crop filter returns empty list for unknown crop', () {
      expect(_filteredPosts(posts, crop: 'Coffee'), isEmpty);
    });
  });

  group('filteredPosts — category filter', () {
    final posts = [
      _makePost(id: 'a', category: 'Pests & Diseases'),
      _makePost(id: 'b', category: 'Growing Guide'),
      _makePost(id: 'c', category: 'Pests & Diseases'),
    ];

    test('category filter matches correctly', () {
      final result = _filteredPosts(posts, category: 'Pests & Diseases');
      expect(result.length, 2);
    });

    test('unmatched category returns empty', () {
      expect(_filteredPosts(posts, category: 'Fertilizer'), isEmpty);
    });
  });

  group('filteredPosts — type filter', () {
    final posts = [
      _makePost(id: 'a', isOfficial: true),
      _makePost(id: 'b', isOfficial: false),
      _makePost(id: 'c', isOfficial: true),
    ];

    test('type=all returns all posts', () {
      expect(_filteredPosts(posts, type: 'all').length, 3);
    });

    test('type=official returns only official posts', () {
      final result = _filteredPosts(posts, type: 'official');
      expect(result.length, 2);
      expect(result.every((p) => p.isOfficial), isTrue);
    });

    test('type=community returns only non-official posts', () {
      final result = _filteredPosts(posts, type: 'community');
      expect(result.length, 1);
      expect(result.first.isOfficial, isFalse);
    });
  });

  group('filteredPosts — hidden posts', () {
    final posts = [
      _makePost(id: 'a', isHidden: false),
      _makePost(id: 'b', isHidden: true),
      _makePost(id: 'c', isHidden: false),
    ];

    test('hidden posts are excluded regardless of filters', () {
      expect(_filteredPosts(posts).length, 2);
      expect(_filteredPosts(posts).every((p) => !p.isHidden), isTrue);
    });
  });

  group('filteredPosts — sort', () {
    final now = DateTime.now();
    final posts = [
      _makePost(id: 'old', likes: 5, distanceKm: 10, timestamp: now.subtract(const Duration(hours: 2))),
      _makePost(id: 'new', likes: 1, distanceKm: 1, timestamp: now.subtract(const Duration(minutes: 5))),
      _makePost(id: 'mid', likes: 3, distanceKm: 5, timestamp: now.subtract(const Duration(hours: 1))),
    ];

    test('sort=newest orders by descending timestamp', () {
      final result = _filteredPosts(posts, sort: 'newest');
      expect(result.map((p) => p.postId).toList(), ['new', 'mid', 'old']);
    });

    test('sort=likes orders by descending like count', () {
      final result = _filteredPosts(posts, sort: 'likes');
      expect(result.map((p) => p.postId).toList(), ['old', 'mid', 'new']);
    });

    test('sort=distance orders by ascending distance', () {
      final result = _filteredPosts(posts, sort: 'distance');
      expect(result.map((p) => p.postId).toList(), ['new', 'mid', 'old']);
    });
  });
}
