import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static const _col = 'posts';

  /// Fetches only posts newer than [since] (for pull-to-refresh).
  /// 3 new posts = 3 reads; 0 new posts = 0 reads.
  static Future<List<Post>> fetchPostsSince(DateTime since) async {
    final snap = await _db
        .collection(_col)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp', descending: true)
        .get();
    return snap.docs
        .map((d) => Post.fromFirestore(d))
        .where((p) => !p.isHidden)
        .toList();
  }

  /// Fetches one page of up to 20 posts (for pagination).
  /// Pass the last DocumentSnapshot of the previous page as [after] to get the next page.
  static Future<({List<Post> posts, DocumentSnapshot? lastDoc})> fetchPostsPage({
    DocumentSnapshot? after,
    int limit = 20,
  }) async {
    var query = _db
        .collection(_col)
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (after != null) query = query.startAfterDocument(after);
    final snap = await query.get();
    final posts = snap.docs
        .map((d) => Post.fromFirestore(d))
        .where((p) => !p.isHidden)
        .toList();
    return (
      posts: posts,
      lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
    );
  }

  /// Saves a post to Firestore (create or update).
  /// For new posts with location data:
  ///  - The main document stores coordinates rounded to ward/municipality level (privacy protection).
  ///  - Exact coordinates are stored in the posts/{id}/private/location sub-collection (admin-only access).
  ///  - The main document and the private sub-collection are written atomically via a Firestore WriteBatch.
  static Future<void> savePost(Post post) async {
    final isNew = post.postId.startsWith('new_');
    final ref = isNew
        ? _db.collection(_col).doc()
        : _db.collection(_col).doc(post.postId);

    final data = post.toFirestore();

    // New post with valid location — overwrite display coordinates rounded to ward level
    final hasValidLocation = isNew &&
        post.location != null &&
        _isValidCoordinate(post.location!.$1, post.location!.$2);

    if (hasValidLocation) {
      final ward = _roundToWardLevel(post.location!.$1, post.location!.$2);
      data['location'] = {'lat': ward.$1, 'lng': ward.$2};
    }

    if (hasValidLocation) {
      // Write main document and exact-coordinate sub-collection atomically in one batch
      final batch = _db.batch();
      batch.set(ref, data);
      batch.set(ref.collection('private').doc('location'), {
        'lat': post.location!.$1,
        'lng': post.location!.$2,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } else {
      await ref.set(data);
    }
  }

  /// Validates that the coordinate is within legal bounds (rejects NaN, Infinity, and out-of-range values).
  static bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  /// Updates the content of an existing post (for the post author or an admin).
  static Future<void> editPost(
      String postId, PostContent content, String editorUid) async {
    await _db.collection(_col).doc(postId).update({
      'content': content.toMap(),
      'editedAt': FieldValue.serverTimestamp(),
      'editedBy': editorUid,
    });
  }

  /// Rounds coordinates to ward/municipality level (~5 km precision) for privacy protection.
  /// Rounds to the nearest 0.05° (~5.5 km grid ≈ ward/municipality level).
  static (double, double) _roundToWardLevel(double lat, double lng) {
    const grid = 0.05; // ≈ 5.5 km per step
    final roundedLat = (lat / grid).round() * grid;
    final roundedLng = (lng / grid).round() * grid;
    return (roundedLat, roundedLng);
  }

  /// Updates specific fields of a post.
  static Future<void> updatePost(
      String postId, Map<String, dynamic> data) async {
    await _db.collection(_col).doc(postId).update(data);
  }

  /// Seeds demo data into Firestore (skips if data already exists).
  /// Returns true if data was seeded, false if skipped (data already present).
  static Future<bool> seedDemoData() async {
    final existing = await _db.collection(_col).limit(1).get();
    if (existing.docs.isNotEmpty) return false;
    await _writeDemoData();
    return true;
  }

  /// Force-seeds demo data (overwrites existing data) — for debugging only.
  static Future<void> forceSeedDemoData() async {
    await _writeDemoData();
  }

  static Future<void> _writeDemoData() async {
    final batch = _db.batch();
    for (final post in _demoData()) {
      final ref = _db.collection(_col).doc(post.postId);
      batch.set(ref, post.toFirestore());
    }
    await batch.commit();
  }

  // ─── Likes ──────────────────────────────────────────────────

  /// Toggles a like (takes the current like state as an argument to avoid an extra Firestore read).
  static Future<void> toggleLike(
      String postId, String userId, bool alreadyLiked) async {
    final ref = _db.collection(_col).doc(postId);
    if (alreadyLiked) {
      await ref.update({
        'likedBy': FieldValue.arrayRemove([userId]),
        'likes': FieldValue.increment(-1),
      });
    } else {
      await ref.update({
        'likedBy': FieldValue.arrayUnion([userId]),
        'likes': FieldValue.increment(1),
      });
    }
  }

  /// Fetches a single post by ID.
  static Future<Post?> fetchPostById(String postId) async {
    final snap = await _db.collection(_col).doc(postId).get();
    if (!snap.exists) return null;
    return Post.fromFirestore(snap);
  }

  // ─── Reports ──────────────────────────────────────────────────

  /// Checks whether this user has already reported the post.
  static Future<bool> hasReported(String postId, String userId) async {
    final snap = await _db
        .collection(_col)
        .doc(postId)
        .collection('reporters')
        .doc(userId)
        .get();
    return snap.exists;
  }

  /// Records a report and hides the post once the threshold of 3 reports is reached.
  static Future<void> reportPost(
      String postId, String userId, String reason) async {
    final reportRef = _db
        .collection(_col)
        .doc(postId)
        .collection('reporters')
        .doc(userId);
    await reportRef.set({
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
    // Check the total report count and hide the post if the threshold is exceeded
    final reporters = await _db
        .collection(_col)
        .doc(postId)
        .collection('reporters')
        .get();
    if (reporters.size >= 3) {
      await _db.collection(_col).doc(postId).update({'isHidden': true});
    }
  }

  // ─── Image upload ────────────────────────────────────────

  /// Uploads an image.
  /// low: Tiny thumbnail (150 px, q35) stored as base64 directly in Firestore — used for cards.
  /// high: Firebase Storage URL (high-res for detail view); falls back to medium-quality base64 (600 px, q78) on failure.
  static Future<({String low, String high})> uploadImage(
      String postId, XFile file) async {
    final rawBytes = await file.readAsBytes();

    // Card thumbnail: very small (acceptable quality since it is displayed small)
    final thumbBytes = await FlutterImageCompress.compressWithList(
      rawBytes,
      quality: 35,
      minWidth: 150,
      minHeight: 150,
    );
    final lowDataUrl =
        'data:image/jpeg;base64,${base64Encode(thumbBytes)}';

    // Detail view: attempt Firebase Storage upload
    String highUrl = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final highRef =
          _storage.ref('images/$postId/high_$timestamp.jpg');
      await highRef.putData(
          rawBytes, SettableMetadata(contentType: 'image/jpeg'));
      highUrl = await highRef.getDownloadURL();
    } catch (e) {
      // If Storage is not configured, fall back to medium-quality base64 (looks fine in detail view)
      debugPrint('[FirebaseService] Storage upload failed, falling back to base64: $e');
      final medBytes = await FlutterImageCompress.compressWithList(
        rawBytes,
        quality: 78,
        minWidth: 800,
        minHeight: 800,
      );
      highUrl = 'data:image/jpeg;base64,${base64Encode(medBytes)}';
    }

    return (low: lowDataUrl, high: highUrl);
  }

  // ─── Dictionary download ──────────────────────────────────────────

  /// Fetches all posts with inDictionary=true.
  /// Pass [since] to fetch only entries created after that date (for incremental download).
  static Future<List<Post>> fetchDictionaryPosts({DateTime? since}) async {
    var query = _db.collection(_col).where('inDictionary', isEqualTo: true);
    if (since != null) {
      query =
          query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await query.get();
    return snap.docs.map((d) => Post.fromFirestore(d)).toList();
  }

  /// Returns the number of dictionary entries (for size estimation).
  /// Pass [since] to return only the count of new entries.
  static Future<int> getDictionaryPostCount({DateTime? since}) async {
    var query = _db.collection(_col).where('inDictionary', isEqualTo: true);
    if (since != null) {
      query =
          query.where('timestamp', isGreaterThan: Timestamp.fromDate(since));
    }
    final snap = await query.count().get();
    return snap.count ?? 0;
  }

  // ─── getDictionaryInfo cache ───────────────────────────────────────
  static ({int count, int textBytes, int thumbBytes, int fullBytes})? _dictInfoCache;
  static DateTime? _dictInfoCacheTime;
  static const _dictInfoCacheDuration = Duration(minutes: 5);

  /// Calculates and returns the actual byte sizes of dictionary entries.
  /// textBytes: JSON byte size of text only.
  /// thumbBytes: Estimated byte size including text and thumbnail images.
  /// fullBytes:  Estimated byte size including text and full-size images.
  /// Pass [excludeIds] to target only the incremental entries not in that set (compared by ID, not timestamp).
  /// When excludeIds is null, an in-memory cache valid for 5 minutes is used.
  static Future<({int count, int textBytes, int thumbBytes, int fullBytes})>
      getDictionaryInfo({Set<String>? excludeIds}) async {
    if (excludeIds == null &&
        _dictInfoCache != null &&
        _dictInfoCacheTime != null &&
        DateTime.now().difference(_dictInfoCacheTime!) < _dictInfoCacheDuration) {
      return _dictInfoCache!;
    }
    final allPosts = await fetchDictionaryPosts();
    final posts = excludeIds != null
        ? allPosts.where((p) => !excludeIds.contains(p.postId)).toList()
        : allPosts;

    int textBytes = 0;
    int thumbsExtra = 0;
    int fullExtra = 0;

    for (final post in posts) {
      final textEntry = {
        'postId': post.postId,
        'userId': post.userId,
        'isOfficial': post.isOfficial,
        'userRole': post.userRole,
        'userName': post.userName,
        'dictCrop': post.dictCrop,
        'dictCategory': post.dictCategory,
        'dictTags': post.dictTags,
        'inDictionary': post.inDictionary,
        'textShort': post.content.textShort,
        'textFull': post.content.textFull,
        'steps': post.content.steps,
      };
      textBytes += utf8.encode(jsonEncode(textEntry)).length;

      // Only count when imageLow is a Firebase Storage URL
      if (post.content.imageLow.startsWith('http')) {
        thumbsExtra += 25 * 1024; // compressed thumbnail ~25 KB
        fullExtra += 25 * 1024;
      }
      // Full-size images
      final realImages = post.content.images
          .where((img) => img.startsWith('http'))
          .length;
      fullExtra += realImages * 200 * 1024; // full image ~200 KB each
    }

    final result = (
      count: posts.length,
      textBytes: textBytes,
      thumbBytes: textBytes + thumbsExtra,
      fullBytes: textBytes + fullExtra,
    );
    if (excludeIds == null) {
      _dictInfoCache = result;
      _dictInfoCacheTime = DateTime.now();
    }
    return result;
  }

  /// Invalidates the dictionary info cache (call after any write to the dictionary).
  static void invalidateDictInfoCache() {
    _dictInfoCache = null;
    _dictInfoCacheTime = null;
  }

  /// Fetches a user's posts with pagination.
  /// Falls back to client-side sorting if the composite index is not yet deployed.
  static Future<({List<Post> posts, DocumentSnapshot? lastDoc})>
      fetchPostsByUser({
    required String userId,
    DocumentSnapshot? after,
    int limit = 20,
  }) async {
    try {
      var query = _db
          .collection(_col)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (after != null) query = query.startAfterDocument(after);
      final snap = await query.get();
      final posts = snap.docs
          .map((d) => Post.fromFirestore(d))
          .where((p) => !p.isHidden)
          .toList();
      return (
        posts: posts,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    } catch (e) {
      // Fallback when the Firestore composite index is not yet deployed:
      // fetch without orderBy and sort on the client side
      debugPrint('[FirebaseService] fetchPostsByUser index error, fallback: $e');
      var query = _db
          .collection(_col)
          .where('userId', isEqualTo: userId)
          .limit(limit);
      if (after != null) query = query.startAfterDocument(after);
      final snap = await query.get();
      final posts = snap.docs
          .map((d) => Post.fromFirestore(d))
          .where((p) => !p.isHidden)
          .toList()
        ..sort((a, b) => (b.timestamp ?? DateTime(0))
            .compareTo(a.timestamp ?? DateTime(0)));
      return (
        posts: posts,
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    }
  }

  /// Deletes a post (post author or admin only).
  /// Also cascade-deletes related notifications using a reverse-lookup index.
  static Future<void> deletePost(String postId) async {
    // Fetch the notification reverse-lookup index and delete related notifications
    try {
      final refs = await _db
          .collection(_col)
          .doc(postId)
          .collection('notif_refs')
          .get();
      if (refs.docs.isNotEmpty) {
        final batch = _db.batch();
        for (final ref in refs.docs) {
          final data = ref.data();
          final userId = data['userId'] as String?;
          final itemId = data['itemId'] as String?;
          if (userId != null && itemId != null) {
            batch.delete(_db
                .collection('notifications')
                .doc(userId)
                .collection('items')
                .doc(itemId));
          }
          batch.delete(ref.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('[FirebaseService] cascade notification delete failed: $e');
    }
    await _db.collection(_col).doc(postId).delete();
  }

  // ─── Notifications ──────────────────────────────────────────────────────

  /// Increments the like counter (managed in users/{uid}.newLikeCount rather than individual documents).
  static Future<void> incrementLikeCount(String userId) async {
    if (userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .update({'newLikeCount': FieldValue.increment(1)});
  }

  /// Resets the like counter (call when the notifications screen is opened).
  static Future<void> resetLikeCount(String userId) async {
    if (userId.isEmpty) return;
    await _db
        .collection('users')
        .doc(userId)
        .update({'newLikeCount': 0});
  }

  /// Sends an admin broadcast (stored in the broadcasts collection).
  static Future<void> sendBroadcast({
    required String title,
    required String body,
    required String sentBy,
  }) async {
    await _db.collection('broadcasts').add({
      'title': title,
      'body': body,
      'sentBy': sentBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ─── User management ──────────────────────────────────────────────

  /// Updates a user's role (admin only).
  static Future<void> setUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).set(
        {'role': role}, SetOptions(merge: true));
  }

  /// Promotes all registered users to admin (for bulk migration).
  static Future<void> promoteAllUsersToAdmin() async {
    final snap = await _db.collection('users').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'role': 'admin'});
    }
    await batch.commit();
  }


  /// Searches users by name or email prefix (admin only).
  /// Uses Firestore range queries for prefix matching. Returns up to 50 results.
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final q = query.trim();
    final end = q.substring(0, q.length - 1) +
        String.fromCharCode(q.codeUnitAt(q.length - 1) + 1);

    // Search by name and email separately, then merge (deduplicating by uid)
    final results = <String, Map<String, dynamic>>{};

    try {
      final byName = await _db
          .collection('users')
          .where('userName', isGreaterThanOrEqualTo: q)
          .where('userName', isLessThan: end)
          .limit(50)
          .get();
      for (final d in byName.docs) {
        results[d.id] = {'uid': d.id, ...d.data()};
      }
    } catch (_) {}

    try {
      final byEmail = await _db
          .collection('users')
          .where('email', isGreaterThanOrEqualTo: q)
          .where('email', isLessThan: end)
          .limit(50)
          .get();
      for (final d in byEmail.docs) {
        results.putIfAbsent(d.id, () => {'uid': d.id, ...d.data()});
      }
    } catch (_) {}

    return results.values.toList();
  }

  /// Saves the FCM device token to users/{uid} in Firestore.
  static Future<void> saveFcmToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set(
        {'fcmToken': token}, SetOptions(merge: true));
  }

  static List<Post> _demoData() {
    final now = DateTime.now();
    return [
      Post(
        postId: 'off_stemborer',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Extension Officer',
        postType: 'report',
        content: const PostContent(
          textShort: 'Maize Stem Borer Alert & Control [Maize] — Gatanga',
          textFull: '## Maize Stem Borer — Alert & Control\n'
              ''
              '\n'
              '## Current Situation\n'
              'Maize stem borer (Busseola fusca / Chilo partellus) reported in multiple farms. '
              'Infestation peaks 3–5 weeks after emergence during long rains.\n'
              '\n'
              '## How to Identify\n'
              '![1]\n'
              '- Small holes on young leaves (shot-hole pattern)\n'
              '- Sawdust-like frass at the leaf whorl\n'
              '- Cream/pink caterpillar (2–3cm) inside damaged leaves\n'
              '\n'
              '## Control Options\n'
              '### Cultural control\n'
              'Remove and destroy crop residues after harvest. Rotate with beans or potatoes.\n'
              '### Biological control (Push-Pull)\n'
              '![2]\n'
              'Intercrop maize with Desmodium — it repels stem borers. Plant Napier grass as a border trap crop.\n'
              '### Chemical control (if severe)\n'
              'Apply Bulldock Star or Thunder OD into the leaf whorl at 2–3 weeks after emergence.\n'
              '\n'
              '## When to Escalate\n'
              'If more than 20% of plants show whorl damage, move to chemical control. '
              'Contact your local extension office for support.',
          steps: [
            'IDENTIFY: Look for small holes on leaves and sawdust-like frass at the whorl. Pull damaged leaves to check for larvae.',
            'CULTURAL CONTROL: Remove and destroy crop residues after harvest. Rotate with beans or potatoes.',
            'BIOLOGICAL CONTROL (Push-Pull): Intercrop with Desmodium + Napier grass border.',
            'CHEMICAL CONTROL (if severe): Apply Bulldock Star into the leaf whorl at 2–3 weeks. Re-apply after 14 days.',
            'MONITOR: Scout twice weekly during weeks 2–6. Escalate if >20% plants are damaged.',
            'REPORT: Photo damaged leaves and post to this app. Contact your local extension office.',
          ],
          imageLow: '🐛',
          images: ['🐛 stem-borer-damage.jpg', '🌿 push-pull-desmodium.jpg'],
        ),
        location: (-0.95, 36.87),
        timestamp: now.subtract(const Duration(hours: 3)),
        isVerified: true,
        distanceKm: 1.5,
        viewMode: 'manual',
        dictCrop: 'Maize',
        dictCategory: 'Pests & Diseases',
        dictTags: ['stem borer', 'busseola', 'chilo', 'pest', 'insect', 'whorl damage'],
      ),
      Post(
        postId: 'off_maize_guide',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Extension Officer',
        postType: 'report',
        content: const PostContent(
          textShort: "Maize Growing Guide [Maize] — Gatanga, Murang'a County",
          textFull: '## Maize Growing Guide\n'
              "### Gatanga sub-county, Murang'a County\n"
              '\n'
              'A complete guide for smallholder maize cultivation in the Central Highlands (1,400–1,800m).\n'
              '\n'
              '## Recommended Varieties\n'
              '- H614 — reliable mid-altitude hybrid\n'
              '- H625 — drought-tolerant option\n'
              '- KH600-23A — early maturity\n'
              '\n'
              '## Planting\n'
              '![1]\n'
              '- Row spacing: 75cm\n'
              '- Plant spacing: 25cm\n'
              '- Seed depth: 5cm\n'
              '- Window: March–April (long rains)\n'
              '\n'
              '## Fertilizer Schedule\n'
              '### At planting\n'
              'Apply DAP (1 tablespoon per hole) mixed with soil before placing seed.\n'
              '### Top dressing (2–3 weeks)\n'
              '![2]\n'
              'Apply CAN fertilizer (1 tbsp per plant) in a ring 10cm from the stem.\n'
              '### Second top dressing (5–6 weeks)\n'
              'Repeat CAN application at knee height. Hill up soil to support roots.\n'
              '\n'
              '## Harvest\n'
              '![3]\n'
              'Harvest when husks are dry and brown, kernels are hard (dent test). Dry to 13% moisture before storage.',
          steps: [
            'Land prep: Clear field, plough 15–20cm. Apply 1 ton/acre manure 2 weeks before planting.',
            'Planting: Certified seed (H614/H625). Spacing 75×25cm, 1 seed per hole at 5cm depth.',
            '1st weeding + Top dress: Weed at 2–3 weeks. Apply CAN (1 tbsp/plant, 10cm from stem).',
            '2nd weeding: Weed at 5–6 weeks (knee height). Hill up soil around base.',
            'Pest scouting: Check weekly for stem borer, FAW, aphids. Report to this app.',
            'Harvest: Husks dry + brown, kernels hard. Dry to 13% moisture.',
          ],
          imageLow: '🌽',
          images: ['🌱 planting-spacing.jpg', '🧪 can-fertilizer.jpg', '🌾 harvest-ready.jpg'],
        ),
        location: (-0.95, 36.87),
        timestamp: now.subtract(const Duration(hours: 6)),
        isVerified: true,
        distanceKm: 1.2,
        viewMode: 'manual',
        dictCrop: 'Maize',
        dictCategory: 'Growing Guide',
        dictTags: ['maize', 'planting', 'fertilizer', 'CAN', 'DAP', 'H614', 'harvest', 'spacing'],
      ),
      Post(
        postId: 'off_faw',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Min. of Agriculture',
        postType: 'report',
        content: const PostContent(
          textShort: "Fall Armyworm (FAW) outbreak confirmed [Maize] — Nakuru / spreading to Murang'a",
          textFull: '## Fall Armyworm (FAW) Outbreak\n'
              "### Nakuru County — spreading to Murang'a\n"
              '\n'
              '## Situation\n'
              'Fall Armyworm (Spodoptera frugiperda) outbreak confirmed. '
              'Larvae feed aggressively on maize whorls and ears. Can destroy a field in days.\n'
              '\n'
              '## How to Identify\n'
              '- Ragged, irregular holes on leaves\n'
              '- Heavy frass (sawdust-like waste) in the whorl\n'
              '- Larvae most active at dawn and dusk\n'
              '\n'
              '## Recommended Action\n'
              '### Organic control\n'
              'Apply Bt-based biopesticide (Bacillus thuringiensis) directly into the whorl.\n'
              '### Chemical control (severe)\n'
              'Use Ampligo (chlorantraniliprole + lambda-cyhalothrin). Follow label strictly.\n'
              '### Manual control\n'
              'Handpick and crush larvae where feasible.\n'
              '\n'
              '## Emergency Contact\n'
              'Contact your local extension office for emergency pesticide supply.',
          steps: [],
          imageLow: '',
          images: [],
        ),
        location: (-0.3, 36.1),
        timestamp: now.subtract(const Duration(days: 1)),
        isVerified: true,
        distanceKm: 8.7,
        viewMode: 'text',
        dictCrop: 'Maize',
        dictCategory: 'Pests & Diseases',
        dictTags: ['fall armyworm', 'FAW', 'spodoptera', 'pest', 'insect', 'whorl', 'Bt'],
      ),
      Post(
        postId: 'off_blight',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Agridict Official',
        postType: 'report',
        content: const PostContent(
          textShort: 'Tomato Late Blight alert [Tomato] — Kiambu County',
          textFull: '## Tomato Late Blight Alert\n'
              '### Kiambu County\n'
              '\n'
              '## Situation\n'
              'Tomato Late Blight (Phytophthora infestans) detected. Spreading rapidly due to high humidity.\n'
              '\n'
              '## How to Identify\n'
              '![1]\n'
              '- Dark brown/black lesions on leaves, starting from edges\n'
              '- White fuzzy mold on leaf undersides (visible in early morning)\n'
              '- Brown spots on stems and fruit\n'
              '\n'
              '## Recommended Action\n'
              '- Apply copper-based fungicide (Copper Oxychloride) every 7–10 days\n'
              '- Remove and destroy infected leaves — do NOT compost\n'
              '- Improve air circulation with proper plant spacing\n'
              '\n'
              '## Prevention\n'
              '- Use resistant varieties where available\n'
              '- Stake plants to keep foliage off the ground\n'
              '- Rotate with non-solanaceous crops',
          steps: [
            'Identify dark brown lesions with white fuzzy mold on leaf undersides',
            'Remove infected leaves and destroy (do NOT compost)',
            'Apply copper-based fungicide every 7–10 days',
            'Improve spacing for air circulation',
          ],
          imageLow: '🍅',
          images: ['🍅 late-blight-symptoms.jpg'],
        ),
        location: (1.1, 36.8),
        timestamp: now.subtract(const Duration(hours: 12)),
        isVerified: true,
        distanceKm: 2.3,
        viewMode: 'manual',
        dictCrop: 'Tomato',
        dictCategory: 'Pests & Diseases',
        dictTags: ['tomato', 'late blight', 'phytophthora', 'fungus', 'copper', 'fungicide'],
      ),
      Post(
        postId: 'usr_001',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Mary Wanjiku',
        postType: 'tweet',
        content: const PostContent(
          textShort:
              'My maize leaves have small holes and there is sawdust stuff in the whorl. Is this stem borer? Help!',
          imageLow: '🌽',
        ),
        location: (-0.96, 36.88),
        timestamp: now.subtract(const Duration(minutes: 45)),
        distanceKm: 1.8,
      ),
      Post(
        postId: 'usr_002',
        isOfficial: false,
        userRole: 'expert',
        userName: 'John Kamau',
        postType: 'tweet',
        content: const PostContent(
          textShort:
              "Mary, that sounds like stem borer. Search 'stem borer' on this app for the official guide. Apply Bulldock into the whorl ASAP.",
          imageLow: '👨‍🌾',
        ),
        location: (-0.95, 36.87),
        timestamp: now.subtract(const Duration(minutes: 30)),
        isVerified: true,
        distanceKm: 1.5,
      ),
      Post(
        postId: 'usr_003',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Grace Njeri',
        postType: 'tweet',
        content: const PostContent(
          textShort:
              'Just planted H614 last week, rains are looking good. Anyone else planting maize in Gatanga?',
        ),
        location: (-0.94, 36.86),
        timestamp: now.subtract(const Duration(hours: 4)),
        distanceKm: 2.1,
      ),
      Post(
        postId: 'usr_004',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Peter Mwangi',
        postType: 'tweet',
        content: const PostContent(
          textShort:
              'When is the best time to apply CAN fertilizer for maize? Plants are about knee height.',
        ),
        location: (-0.97, 36.89),
        timestamp: now.subtract(const Duration(hours: 1)),
        distanceKm: 2.5,
      ),
      Post(
        postId: 'usr_005',
        isOfficial: false,
        userRole: 'expert',
        userName: 'John Kamau',
        postType: 'tweet',
        content: const PostContent(
          textShort:
              'Peter, knee height is perfect for 2nd top dressing. 1 tbsp CAN per plant, 10cm from stem. Wait for rain first.',
          imageLow: '👨‍🌾',
        ),
        location: (-0.95, 36.87),
        timestamp: now.subtract(const Duration(minutes: 50)),
        isVerified: true,
        distanceKm: 1.5,
      ),
    ];
  }

  // ─── Analytics ────────────────────────────────────────────────

  /// Records an app open event.
  /// [lastOpenDate] is the value read from users/{uid} (already fetched in _loadRole).
  /// If it's the first open today, also increments uniqueUsers; openCount is incremented every time.
  /// Zero extra Firestore reads (piggybacks on the existing read in _loadRole).
  static Future<void> recordAppOpen(String uid, String? lastOpenDate) async {
    final today = _dateKey(DateTime.now());
    final ref = _db.collection('analytics').doc(today);
    final isNewDay = lastOpenDate != today;

    if (isNewDay) {
      // First open of the day: increment openCount + uniqueUsers and update lastOpenDate
      await Future.wait([
        ref.set(
          {'openCount': FieldValue.increment(1), 'uniqueUsers': FieldValue.increment(1), 'date': today},
          SetOptions(merge: true),
        ),
        _db.collection('users').doc(uid).update({'lastOpenDate': today}),
      ]);
    } else {
      // Subsequent open on the same day: increment openCount only
      await ref.set(
        {'openCount': FieldValue.increment(1), 'date': today},
        SetOptions(merge: true),
      );
    }
  }

  /// Fetches analytics data for the past [days] days (admin only).
  /// Incurs [days] Firestore reads.
  static Future<List<Map<String, dynamic>>> fetchAnalytics({int days = 30}) async {
    final now = DateTime.now();
    final futures = List.generate(days, (i) {
      final date = now.subtract(Duration(days: i));
      return _db.collection('analytics').doc(_dateKey(date)).get();
    });
    final snaps = await Future.wait(futures);
    return snaps.map((s) {
      final data = s.data() ?? {};
      return {
        'date': s.id,
        'openCount': (data['openCount'] as int?) ?? 0,
        'uniqueUsers': (data['uniqueUsers'] as int?) ?? 0,
      };
    }).toList().reversed.toList(); // sort oldest first
  }

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Returns {tweetCount, reportCount, dictCount, userCount}
  static Future<Map<String, int>> fetchPostCounts() async {
    final results = await Future.wait([
      _db.collection(_col).where('postType', isEqualTo: 'tweet').where('isHidden', isEqualTo: false).count().get(),
      _db.collection(_col).where('postType', isEqualTo: 'report').where('isHidden', isEqualTo: false).count().get(),
      _db.collection(_col).where('inDictionary', isEqualTo: true).where('isHidden', isEqualTo: false).count().get(),
      _db.collection('users').count().get(),
    ]);
    return {
      'tweetCount': results[0].count ?? 0,
      'reportCount': results[1].count ?? 0,
      'dictCount': results[2].count ?? 0,
      'userCount': results[3].count ?? 0,
    };
  }
}
