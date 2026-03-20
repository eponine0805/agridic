import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // 'like' | 'dict_added' | 'broadcast'
  final String title;
  final String body;
  final String? postId;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.postId,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final ts = m['timestamp'];
    return AppNotification(
      id: doc.id,
      type: (m['type'] ?? 'broadcast') as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      postId: m['postId'] as String?,
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      isRead: (m['isRead'] ?? false) as bool,
    );
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> m) {
    final ts = m['timestamp'];
    DateTime timestamp;
    if (ts is Timestamp) {
      timestamp = ts.toDate();
    } else if (ts is String) {
      timestamp = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      timestamp = DateTime.now();
    }
    return AppNotification(
      id: id,
      type: (m['type'] ?? 'broadcast') as String,
      title: (m['title'] ?? '') as String,
      body: (m['body'] ?? '') as String,
      postId: m['postId'] as String?,
      timestamp: timestamp,
      isRead: (m['isRead'] ?? false) as bool,
    );
  }
}
