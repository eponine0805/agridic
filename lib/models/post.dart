import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ViewMode { text, manual, visual }

enum PostType { quick, report }

enum UserRole { farmer, expert, admin }

@immutable
class PostContent {
  final String textShort;
  final String textFull;
  final String textFullManual;
  final String textFullVisual;
  final List<String> steps;
  final String imageLow;
  final String imageHigh;
  final List<String> images;

  const PostContent({
    this.textShort = '',
    this.textFull = '',
    this.textFullManual = '',
    this.textFullVisual = '',
    this.steps = const [],
    this.imageLow = '',
    this.imageHigh = '',
    this.images = const [],
  });

  factory PostContent.fromMap(Map<String, dynamic> m) => PostContent(
        textShort: (m['textShort'] ?? '') as String,
        textFull: (m['textFull'] ?? '') as String,
        textFullManual: (m['textFullManual'] ?? '') as String,
        textFullVisual: (m['textFullVisual'] ?? '') as String,
        steps: List<String>.from(m['steps'] ?? []),
        imageLow: (m['imageLow'] ?? '') as String,
        imageHigh: (m['imageHigh'] ?? '') as String,
        images: List<String>.from(m['images'] ?? []),
      );

  Map<String, dynamic> toMap() => {
        'textShort': textShort,
        'textFull': textFull,
        'textFullManual': textFullManual,
        'textFullVisual': textFullVisual,
        'steps': steps,
        'imageLow': imageLow,
        'imageHigh': imageHigh,
        'images': images,
      };
}

class Post {
  final String postId;
  final bool isOfficial;
  final String userRole;
  final String userName;
  final PostContent content;
  final (double, double)? location;
  final DateTime? timestamp;
  final bool isVerified;
  int reports;
  bool isHidden;
  final double distanceKm;
  final String viewMode;
  final String dictCrop;
  final String dictCategory;
  final List<String> dictTags;

  Post({
    required this.postId,
    required this.isOfficial,
    required this.userRole,
    required this.userName,
    required this.content,
    this.location,
    this.timestamp,
    this.isVerified = false,
    this.reports = 0,
    this.isHidden = false,
    this.distanceKm = 0,
    this.viewMode = 'text',
    this.dictCrop = '',
    this.dictCategory = '',
    this.dictTags = const [],
  });

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final locMap = m['location'] as Map<String, dynamic>?;
    final ts = m['timestamp'];
    return Post(
      postId: doc.id,
      isOfficial: (m['isOfficial'] ?? false) as bool,
      userRole: (m['userRole'] ?? 'farmer') as String,
      userName: (m['userName'] ?? '') as String,
      content: PostContent.fromMap(
          (m['content'] as Map<String, dynamic>?) ?? {}),
      location: locMap != null
          ? ((locMap['lat'] as num).toDouble(),
              (locMap['lng'] as num).toDouble())
          : null,
      timestamp: ts is Timestamp ? ts.toDate() : null,
      isVerified: (m['isVerified'] ?? false) as bool,
      reports: (m['reports'] ?? 0) as int,
      isHidden: (m['isHidden'] ?? false) as bool,
      distanceKm: ((m['distanceKm'] as num?) ?? 0).toDouble(),
      viewMode: (m['viewMode'] ?? 'text') as String,
      dictCrop: (m['dictCrop'] ?? '') as String,
      dictCategory: (m['dictCategory'] ?? '') as String,
      dictTags: List<String>.from(m['dictTags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'isOfficial': isOfficial,
        'userRole': userRole,
        'userName': userName,
        'content': content.toMap(),
        if (location != null)
          'location': {'lat': location!.$1, 'lng': location!.$2},
        'timestamp': timestamp != null
            ? Timestamp.fromDate(timestamp!)
            : FieldValue.serverTimestamp(),
        'isVerified': isVerified,
        'reports': reports,
        'isHidden': isHidden,
        'distanceKm': distanceKm,
        'viewMode': viewMode,
        'dictCrop': dictCrop,
        'dictCategory': dictCategory,
        'dictTags': dictTags,
      };
}
