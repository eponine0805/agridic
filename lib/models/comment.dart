import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String commentId;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String text;
  final DateTime? timestamp;

  Comment({
    required this.commentId,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.text,
    this.timestamp,
  });

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final ts = m['timestamp'];
    return Comment(
      commentId: doc.id,
      authorId: (m['authorId'] ?? '') as String,
      authorName: (m['authorName'] ?? '') as String,
      authorRole: (m['authorRole'] ?? 'farmer') as String,
      text: (m['text'] ?? '') as String,
      timestamp: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'authorId': authorId,
        'authorName': authorName,
        'authorRole': authorRole,
        'text': text,
        'timestamp': timestamp != null
            ? Timestamp.fromDate(timestamp!)
            : FieldValue.serverTimestamp(),
      };
}
