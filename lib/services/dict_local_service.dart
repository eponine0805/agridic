import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/post.dart';

/// Manages the offline dictionary cache stored as a JSON file on device.
/// Uses path_provider (application documents directory) instead of
/// SharedPreferences to avoid size limits.
class DictLocalService {
  static const _cacheFile = 'dict_cache.json';
  static const _metaFile = 'dict_meta.json';

  static Future<File> _file(String name) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$name');
  }

  /// Save [posts] to local storage with the given download [mode].
  /// mode: 0 = text only, 1 = text + thumbnails, 2 = text + full images
  static Future<void> save(List<Post> posts, int mode) async {
    final data = posts.map((p) => _toMap(p, mode)).toList();
    final f = await _file(_cacheFile);
    await f.writeAsString(jsonEncode(data));

    final meta = await _file(_metaFile);
    await meta.writeAsString(jsonEncode({
      'savedAt': DateTime.now().toIso8601String(),
      'mode': mode,
      'count': posts.length,
    }));
  }

  /// Load cached posts from local storage.
  static Future<({List<Post> posts, DateTime? savedAt, int mode})> load() async {
    try {
      final f = await _file(_cacheFile);
      if (!await f.exists()) return (posts: <Post>[], savedAt: null, mode: 0);

      final list = jsonDecode(await f.readAsString()) as List;
      final posts = list.map((m) => _fromMap(m as Map<String, dynamic>)).toList();

      DateTime? savedAt;
      int mode = 0;
      final mf = await _file(_metaFile);
      if (await mf.exists()) {
        final meta = jsonDecode(await mf.readAsString()) as Map<String, dynamic>;
        savedAt = DateTime.tryParse((meta['savedAt'] as String?) ?? '');
        mode = (meta['mode'] as int?) ?? 0;
      }
      return (posts: posts, savedAt: savedAt, mode: mode);
    } catch (_) {
      return (posts: <Post>[], savedAt: null, mode: 0);
    }
  }

  /// Returns true if a cache file exists on disk.
  static Future<bool> hasCache() async {
    final f = await _file(_cacheFile);
    return f.exists();
  }

  // ─── serialization ────────────────────────────────────────────────────────

  static Map<String, dynamic> _toMap(Post p, int mode) => {
        'postId': p.postId,
        'userId': p.userId,
        'isOfficial': p.isOfficial,
        'userRole': p.userRole,
        'userName': p.userName,
        'dictCrop': p.dictCrop,
        'dictCategory': p.dictCategory,
        'dictTags': p.dictTags,
        'inDictionary': p.inDictionary,
        'viewMode': p.viewMode,
        'content': {
          'textShort': p.content.textShort,
          'textFull': p.content.textFull,
          'textFullManual': p.content.textFullManual,
          'textFullVisual': p.content.textFullVisual,
          'steps': p.content.steps,
          'imageLow': mode >= 1 ? p.content.imageLow : '',
          'imageHigh': mode >= 2 ? p.content.imageHigh : '',
          'images': mode >= 2 ? p.content.images : <String>[],
        },
      };

  static Post _fromMap(Map<String, dynamic> m) => Post(
        postId: (m['postId'] ?? '') as String,
        userId: (m['userId'] ?? '') as String,
        isOfficial: (m['isOfficial'] ?? true) as bool,
        userRole: (m['userRole'] ?? 'expert') as String,
        userName: (m['userName'] ?? '') as String,
        content: PostContent.fromMap(
            (m['content'] as Map<String, dynamic>?) ?? {}),
        viewMode: (m['viewMode'] ?? 'text') as String,
        dictCrop: (m['dictCrop'] ?? '') as String,
        dictCategory: (m['dictCategory'] ?? '') as String,
        dictTags: List<String>.from(m['dictTags'] ?? []),
        inDictionary: (m['inDictionary'] ?? true) as bool,
      );
}
