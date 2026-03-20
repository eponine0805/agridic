import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

/// オフライン時に作成した投稿をローカルに保存し、
/// オンライン復帰時にFirestoreへアップロードするキュー
class OfflineQueueService {
  static const _key = 'offline_post_queue';

  /// キューに投稿を追加
  /// [localTweetImagePath] : ツイート型の添付画像ローカルパス（オフライン時）
  static Future<void> enqueue(Post post, {String? localTweetImagePath}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<dynamic> queue =
        raw != null ? jsonDecode(raw) as List<dynamic> : [];
    final entry = <String, dynamic>{'post': post.toJson()};
    if (localTweetImagePath != null) {
      entry['localTweetImagePath'] = localTweetImagePath;
    }
    queue.add(entry);
    await prefs.setString(_key, jsonEncode(queue));
  }

  /// キューの全エントリを取得
  /// 各エントリは {'post': {...}, 'localTweetImagePath': '...'} の形式
  /// （旧フォーマットの直接 postJson も後方互換で返す）
  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// キューが空かどうか
  static Future<bool> isEmpty() async {
    final items = await getAll();
    return items.isEmpty;
  }

  /// キューを空にする
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// キューの件数
  static Future<int> count() async {
    final items = await getAll();
    return items.length;
  }
}
