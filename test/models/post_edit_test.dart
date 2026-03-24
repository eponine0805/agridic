import 'package:flutter_test/flutter_test.dart';
import 'package:agridic/models/post.dart';

Post _basePost() => Post(
      postId: 'p1',
      isOfficial: false,
      userRole: 'farmer',
      userName: 'Alice',
      content: const PostContent(textShort: 'original'),
    );

void main() {
  group('Post editedAt / editedBy fields', () {
    test('defaults to null editedAt and empty editedBy', () {
      final p = _basePost();
      expect(p.editedAt, isNull);
      expect(p.editedBy, '');
    });

    test('copyWith sets editedAt and editedBy', () {
      final now = DateTime(2025, 6, 1, 12, 0);
      final p = _basePost().copyWith(editedAt: now, editedBy: 'uid_admin');
      expect(p.editedAt, now);
      expect(p.editedBy, 'uid_admin');
    });

    test('copyWith without edit fields preserves original nulls', () {
      final p = _basePost().copyWith(content: const PostContent(textShort: 'new'));
      expect(p.editedAt, isNull);
      expect(p.editedBy, '');
      expect(p.content.textShort, 'new');
    });

    test('toJson roundtrips editedAt and editedBy via fromMap', () {
      final now = DateTime(2025, 6, 1, 12, 0);
      final p = _basePost().copyWith(editedAt: now, editedBy: 'uid_x');
      final json = p.toJson();
      expect(json['editedAt'], isA<String>());
      expect(json['editedBy'], 'uid_x');

      final restored = Post.fromMap(json);
      expect(restored.editedAt, now);
      expect(restored.editedBy, 'uid_x');
    });

    test('fromMap with no editedAt gives null', () {
      final json = _basePost().toJson();
      // ensure no edit keys present
      json.remove('editedAt');
      json.remove('editedBy');
      final p = Post.fromMap(json);
      expect(p.editedAt, isNull);
      expect(p.editedBy, '');
    });

    test('toFirestore omits editedAt/editedBy when unset', () {
      final map = _basePost().toFirestore();
      expect(map.containsKey('editedAt'), isFalse);
      expect(map.containsKey('editedBy'), isFalse);
    });

    test('toFirestore includes editedAt/editedBy when set', () {
      final now = DateTime(2025, 6, 1);
      final p = _basePost().copyWith(editedAt: now, editedBy: 'admin');
      final map = p.toFirestore();
      expect(map.containsKey('editedAt'), isTrue);
      expect(map['editedBy'], 'admin');
    });
  });
}
