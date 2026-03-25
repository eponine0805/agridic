import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/post.dart';

/// Persists posts created while offline and uploads them to Firestore
/// when connectivity is restored.
class OfflineQueueService {
  static const _key = 'offline_post_queue';

  /// Maximum number of posts that can be queued (protects device storage).
  static const maxQueueSize = 200;

  /// Adds a post to the queue.
  /// [localTweetImagePath]: local path to an attached image for tweet-type posts (offline only).
  /// Returns false if the queue is full.
  static Future<bool> enqueue(Post post, {String? localTweetImagePath}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final List<dynamic> queue =
        raw != null ? jsonDecode(raw) as List<dynamic> : [];
    if (queue.length >= maxQueueSize) return false; // queue full
    final entry = <String, dynamic>{'post': post.toJson()};
    if (localTweetImagePath != null) {
      entry['localTweetImagePath'] = localTweetImagePath;
    }
    queue.add(entry);
    await prefs.setString(_key, jsonEncode(queue));
    return true;
  }

  /// Returns all queued entries.
  /// Each entry has the shape {'post': {...}, 'localTweetImagePath': '...'}.
  /// Legacy entries stored as plain postJson are also returned for backward compatibility.
  static Future<List<Map<String, dynamic>>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  /// Returns true if the queue is empty.
  static Future<bool> isEmpty() async {
    final items = await getAll();
    return items.isEmpty;
  }

  /// Updates a single entry at [index] (used to persist uploaded image URLs).
  static Future<void> updateAt(int index, Map<String, dynamic> entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    if (index < 0 || index >= list.length) return;
    list[index] = entry;
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Removes a single entry at [index] after it has been successfully posted.
  static Future<void> removeAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await prefs.setString(_key, jsonEncode(list));
  }

  /// Clears the entire queue.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Returns the number of queued posts.
  static Future<int> count() async {
    final items = await getAll();
    return items.length;
  }
}
