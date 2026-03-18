import 'package:flutter/foundation.dart';

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
}
