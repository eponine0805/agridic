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
  final String userId;
  final bool isOfficial;
  final String userRole;
  final String userName;
  final PostContent content;
  final (double, double)? location;
  final DateTime? timestamp;
  final bool isVerified;
  final int reports;
  final bool isHidden;
  final int likes;
  final List<String> likedBy;
  final double distanceKm;
  final String viewMode;
  final String dictCrop;
  final String dictCategory;
  final List<String> dictTags;
  final bool inDictionary;
  /// 'tweet' | 'report' | '' (empty = legacy, inferred from dictCrop)
  final String postType;
  /// Author avatar image (base64 data URL) — embedded at post creation time.
  final String avatarBase64;
  /// Timestamp of the last edit (null if never edited).
  final DateTime? editedAt;
  /// UID of the last editor.
  final String editedBy;

  Post({
    required this.postId,
    this.userId = '',
    required this.isOfficial,
    required this.userRole,
    required this.userName,
    required this.content,
    this.location,
    this.timestamp,
    this.isVerified = false,
    this.reports = 0,
    this.isHidden = false,
    this.likes = 0,
    this.likedBy = const [],
    this.distanceKm = 0,
    this.viewMode = 'text',
    this.dictCrop = '',
    this.dictCategory = '',
    this.dictTags = const [],
    this.inDictionary = false,
    this.postType = '',
    this.avatarBase64 = '',
    this.editedAt,
    this.editedBy = '',
  });

  Post copyWith({
    String? userId,
    bool? isOfficial,
    String? userRole,
    String? userName,
    PostContent? content,
    (double, double)? location,
    DateTime? timestamp,
    bool? isVerified,
    int? reports,
    bool? isHidden,
    int? likes,
    List<String>? likedBy,
    double? distanceKm,
    String? viewMode,
    String? dictCrop,
    String? dictCategory,
    List<String>? dictTags,
    bool? inDictionary,
    String? postType,
    String? avatarBase64,
    DateTime? editedAt,
    String? editedBy,
  }) =>
      Post(
        postId: postId,
        userId: userId ?? this.userId,
        isOfficial: isOfficial ?? this.isOfficial,
        userRole: userRole ?? this.userRole,
        userName: userName ?? this.userName,
        content: content ?? this.content,
        location: location ?? this.location,
        timestamp: timestamp ?? this.timestamp,
        isVerified: isVerified ?? this.isVerified,
        reports: reports ?? this.reports,
        isHidden: isHidden ?? this.isHidden,
        likes: likes ?? this.likes,
        likedBy: likedBy ?? this.likedBy,
        distanceKm: distanceKm ?? this.distanceKm,
        viewMode: viewMode ?? this.viewMode,
        dictCrop: dictCrop ?? this.dictCrop,
        dictCategory: dictCategory ?? this.dictCategory,
        dictTags: dictTags ?? this.dictTags,
        inDictionary: inDictionary ?? this.inDictionary,
        postType: postType ?? this.postType,
        avatarBase64: avatarBase64 ?? this.avatarBase64,
        editedAt: editedAt ?? this.editedAt,
        editedBy: editedBy ?? this.editedBy,
      );

  /// Returns true if this is a tweet (handles legacy posts where postType is empty).
  bool get isTweet => postType == 'tweet' ||
      (postType.isEmpty && dictCrop.isEmpty && content.steps.isEmpty &&
          content.textFull.isEmpty && content.textFullManual.isEmpty);
  bool get isReport => !isTweet;

  /// Deserializes a Post from an offline queue JSON map.
  factory Post.fromMap(Map<String, dynamic> m) {
    final locMap = m['location'] as Map<String, dynamic>?;
    final ts = m['timestamp'];
    DateTime? timestamp;
    if (ts is String) timestamp = DateTime.tryParse(ts);
    final ets = m['editedAt'];
    DateTime? editedAt;
    if (ets is String) editedAt = DateTime.tryParse(ets);
    return Post(
      postId: (m['postId'] ?? m['id'] ?? '') as String,
      userId: (m['userId'] ?? '') as String,
      isOfficial: (m['isOfficial'] ?? false) as bool,
      userRole: (m['userRole'] ?? 'farmer') as String,
      userName: (m['userName'] ?? '') as String,
      content: PostContent.fromMap(
          (m['content'] as Map<String, dynamic>?) ?? {}),
      location: locMap != null &&
              locMap['lat'] != null &&
              locMap['lng'] != null
          ? ((locMap['lat'] as num).toDouble(),
              (locMap['lng'] as num).toDouble())
          : null,
      timestamp: timestamp,
      isVerified: (m['isVerified'] ?? false) as bool,
      reports: (m['reports'] ?? 0) as int,
      isHidden: (m['isHidden'] ?? false) as bool,
      likes: (m['likes'] ?? 0) as int,
      likedBy: List<String>.from(m['likedBy'] ?? []),
      distanceKm: ((m['distanceKm'] as num?) ?? 0).toDouble(),
      viewMode: (m['viewMode'] ?? 'text') as String,
      dictCrop: (m['dictCrop'] ?? '') as String,
      dictCategory: (m['dictCategory'] ?? '') as String,
      dictTags: List<String>.from(m['dictTags'] ?? []),
      inDictionary: (m['inDictionary'] ?? false) as bool,
      postType: (m['postType'] ?? '') as String,
      avatarBase64: (m['avatarBase64'] ?? '') as String,
      editedAt: editedAt,
      editedBy: (m['editedBy'] ?? '') as String,
    );
  }

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final locMap = m['location'] as Map<String, dynamic>?;
    final ts = m['timestamp'];
    final ets = m['editedAt'];
    return Post(
      postId: doc.id,
      userId: (m['userId'] ?? '') as String,
      isOfficial: (m['isOfficial'] ?? false) as bool,
      userRole: (m['userRole'] ?? 'farmer') as String,
      userName: (m['userName'] ?? '') as String,
      content: PostContent.fromMap(
          (m['content'] as Map<String, dynamic>?) ?? {}),
      location: locMap != null &&
              locMap['lat'] != null &&
              locMap['lng'] != null
          ? ((locMap['lat'] as num).toDouble(),
              (locMap['lng'] as num).toDouble())
          : null,
      timestamp: ts is Timestamp ? ts.toDate() : null,
      isVerified: (m['isVerified'] ?? false) as bool,
      reports: (m['reports'] ?? 0) as int,
      isHidden: (m['isHidden'] ?? false) as bool,
      likes: (m['likes'] ?? 0) as int,
      likedBy: List<String>.from(m['likedBy'] ?? []),
      distanceKm: ((m['distanceKm'] as num?) ?? 0).toDouble(),
      viewMode: (m['viewMode'] ?? 'text') as String,
      dictCrop: (m['dictCrop'] ?? '') as String,
      dictCategory: (m['dictCategory'] ?? '') as String,
      dictTags: List<String>.from(m['dictTags'] ?? []),
      inDictionary: (m['inDictionary'] ?? false) as bool,
      postType: (m['postType'] ?? '') as String,
      avatarBase64: (m['avatarBase64'] ?? '') as String,
      editedAt: ets is Timestamp ? ets.toDate() : null,
      editedBy: (m['editedBy'] ?? '') as String,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
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
        'likes': likes,
        'likedBy': likedBy,
        'distanceKm': distanceKm,
        'viewMode': viewMode,
        'dictCrop': dictCrop,
        'dictCategory': dictCategory,
        'dictTags': dictTags,
        'inDictionary': inDictionary,
        'postType': postType,
        'avatarBase64': avatarBase64,
        if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
        if (editedBy.isNotEmpty) 'editedBy': editedBy,
      };

  /// Serializes the post to JSON for offline queue storage.
  Map<String, dynamic> toJson() => {
        'postId': postId,
        'userId': userId,
        'isOfficial': isOfficial,
        'userRole': userRole,
        'userName': userName,
        'content': content.toMap(),
        if (location != null)
          'location': {'lat': location!.$1, 'lng': location!.$2},
        'timestamp': timestamp?.toIso8601String(),
        'isVerified': isVerified,
        'reports': reports,
        'isHidden': isHidden,
        'likes': likes,
        'likedBy': likedBy,
        'distanceKm': distanceKm,
        'viewMode': viewMode,
        'dictCrop': dictCrop,
        'dictCategory': dictCategory,
        'dictTags': dictTags,
        'inDictionary': inDictionary,
        'postType': postType,
        'avatarBase64': avatarBase64,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
        if (editedBy.isNotEmpty) 'editedBy': editedBy,
      };
}
