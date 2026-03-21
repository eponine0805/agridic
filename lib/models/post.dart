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
  /// 投稿者のアバター画像（base64 data URL）— 投稿作成時に埋め込み
  final String avatarBase64;

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
  });

  Post copyWith({
    int? likes,
    List<String>? likedBy,
    bool? isHidden,
    int? reports,
  }) =>
      Post(
        postId: postId,
        userId: userId,
        isOfficial: isOfficial,
        userRole: userRole,
        userName: userName,
        content: content,
        location: location,
        timestamp: timestamp,
        isVerified: isVerified,
        reports: reports ?? this.reports,
        isHidden: isHidden ?? this.isHidden,
        likes: likes ?? this.likes,
        likedBy: likedBy ?? this.likedBy,
        distanceKm: distanceKm,
        viewMode: viewMode,
        dictCrop: dictCrop,
        dictCategory: dictCategory,
        dictTags: dictTags,
        inDictionary: inDictionary,
        postType: postType,
        avatarBase64: avatarBase64,
      );

  /// tweet か report かを判定（postType フィールドが空の旧データに対応）
  bool get isTweet => postType == 'tweet' ||
      (postType.isEmpty && dictCrop.isEmpty && content.steps.isEmpty &&
          content.textFull.isEmpty && content.textFullManual.isEmpty);
  bool get isReport => !isTweet;

  /// オフラインキューのJSONから復元する
  factory Post.fromMap(Map<String, dynamic> m) {
    final locMap = m['location'] as Map<String, dynamic>?;
    final ts = m['timestamp'];
    DateTime? timestamp;
    if (ts is String) timestamp = DateTime.tryParse(ts);
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
    );
  }

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data()!;
    final locMap = m['location'] as Map<String, dynamic>?;
    final ts = m['timestamp'];
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
      };

  /// JSON シリアライズ用（オフラインキュー保存）
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
      };
}
