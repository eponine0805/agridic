import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/comment.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static const _col = 'posts';

  /// Firestoreからポスト一覧をリアルタイムストリームで取得
  static Stream<List<Post>> streamPosts() {
    return _db
        .collection(_col)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Post.fromFirestore(d))
            .where((p) => !p.isHidden)
            .toList());
  }

  /// ポストをFirestoreに保存（新規作成 or 更新）
  static Future<void> savePost(Post post) async {
    final isNew = post.postId.startsWith('new_');
    final ref = isNew
        ? _db.collection(_col).doc()
        : _db.collection(_col).doc(post.postId);
    await ref.set(post.toFirestore());
  }

  /// ポストの特定フィールドを更新
  static Future<void> updatePost(
      String postId, Map<String, dynamic> data) async {
    await _db.collection(_col).doc(postId).update(data);
  }

  /// デモデータをFirestoreに投入（既にデータがある場合はスキップ）
  /// 戻り値: true = 投入した, false = スキップ（既にデータあり）
  static Future<bool> seedDemoData() async {
    final existing = await _db.collection(_col).limit(1).get();
    if (existing.docs.isNotEmpty) return false;

    final batch = _db.batch();
    for (final post in _demoData()) {
      final ref = _db.collection(_col).doc(post.postId);
      batch.set(ref, post.toFirestore());
    }
    await batch.commit();
    return true;
  }

  // ─── いいね ──────────────────────────────────────────────────

  /// いいねをトグル（済みなら解除、未なら追加）
  static Future<void> toggleLike(String postId, String userId) async {
    final ref = _db.collection(_col).doc(postId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final likedBy = List<String>.from(data['likedBy'] ?? []);
    if (likedBy.contains(userId)) {
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

  // ─── コメント ──────────────────────────────────────────────

  static Stream<List<Comment>> streamComments(String postId) {
    return _db
        .collection(_col)
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Comment.fromFirestore(d)).toList());
  }

  static Future<void> addComment(String postId, Comment comment) async {
    await _db
        .collection(_col)
        .doc(postId)
        .collection('comments')
        .add(comment.toFirestore());
  }

  // ─── 通報 ──────────────────────────────────────────────────

  /// このユーザーが既に通報済みか確認
  static Future<bool> hasReported(String postId, String userId) async {
    final snap = await _db
        .collection(_col)
        .doc(postId)
        .collection('reporters')
        .doc(userId)
        .get();
    return snap.exists;
  }

  /// 通報を記録し、3件以上になったら非表示にする
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
    // 通報数を確認して閾値を超えたら非表示
    final reporters = await _db
        .collection(_col)
        .doc(postId)
        .collection('reporters')
        .get();
    if (reporters.size >= 3) {
      await _db.collection(_col).doc(postId).update({'isHidden': true});
    }
  }

  // ─── 画像アップロード ────────────────────────────────────────

  /// 画像をアップロードする
  /// low: サムネイルをbase64 data URLとしてFirestoreに直接格納（Storage不要）
  /// high: フル解像度をFirebase Storageにアップロード（失敗しても続行）
  static Future<({String low, String high})> uploadImage(
      String postId, XFile file) async {
    final rawBytes = await file.readAsBytes();

    // サムネイル: 640px以下に圧縮してbase64 data URLとして返す
    // → Firebase Storageのルール設定不要でFirestoreに直接格納できる
    final thumbBytes = await FlutterImageCompress.compressWithList(
      rawBytes,
      quality: 72,
      minWidth: 640,
      minHeight: 640,
    );
    final lowDataUrl =
        'data:image/jpeg;base64,${base64Encode(thumbBytes)}';

    // フル解像度: Firebase Storageに試みる（未設定でも投稿はできる）
    String highUrl = '';
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final highRef =
          _storage.ref('images/$postId/high_$timestamp.jpg');
      await highRef.putData(
          rawBytes, SettableMetadata(contentType: 'image/jpeg'));
      highUrl = await highRef.getDownloadURL();
    } catch (_) {
      // Storage未設定時はスキップ（サムネイルは常に利用可能）
    }

    return (low: lowDataUrl, high: highUrl);
  }

  // ─── 辞書ダウンロード ──────────────────────────────────────────

  /// inDictionary=true のポスト一覧を全件取得
  static Future<List<Post>> fetchDictionaryPosts() async {
    final snap = await _db
        .collection(_col)
        .where('inDictionary', isEqualTo: true)
        .get();
    return snap.docs.map((d) => Post.fromFirestore(d)).toList();
  }

  /// 辞書エントリ数を取得（サイズ見積もり用）
  static Future<int> getDictionaryPostCount() async {
    final snap = await _db
        .collection(_col)
        .where('inDictionary', isEqualTo: true)
        .get();
    return snap.size;
  }

  /// 辞書エントリの実バイト数を計算して返す
  /// textBytes: テキストのみのJSONバイト数
  /// thumbBytes: テキスト + サムネイル画像込みの推定バイト数
  /// fullBytes:  テキスト + フル画像込みの推定バイト数
  static Future<({int count, int textBytes, int thumbBytes, int fullBytes})>
      getDictionaryInfo() async {
    final posts = await fetchDictionaryPosts();

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

      // imageLow が Firebase Storage URL の場合のみカウント
      if (post.content.imageLow.startsWith('http')) {
        thumbsExtra += 25 * 1024; // 圧縮サムネイル ~25KB
        fullExtra += 25 * 1024;
      }
      // フル画像
      final realImages = post.content.images
          .where((img) => img.startsWith('http'))
          .length;
      fullExtra += realImages * 200 * 1024; // フル画像 ~200KB/枚
    }

    return (
      count: posts.length,
      textBytes: textBytes,
      thumbBytes: textBytes + thumbsExtra,
      fullBytes: textBytes + fullExtra,
    );
  }

  /// 投稿を削除（投稿者本人またはadminのみ）
  static Future<void> deletePost(String postId) async {
    await _db.collection(_col).doc(postId).delete();
  }

  // ─── ユーザー管理 ──────────────────────────────────────────────

  /// ユーザーのロールを更新（admin専用）
  static Future<void> setUserRole(String uid, String role) async {
    await _db.collection('users').doc(uid).set(
        {'role': role}, SetOptions(merge: true));
  }

  /// 全登録ユーザーを admin に昇格する（一括マイグレーション用）
  static Future<void> promoteAllUsersToAdmin() async {
    final snap = await _db.collection('users').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'role': 'admin'});
    }
    await batch.commit();
  }


  /// ユーザー一覧をFirestoreから取得
  static Future<List<Map<String, dynamic>>> fetchUsers() async {
    final snap = await _db.collection('users').get();
    return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
  }

  static List<Post> _demoData() {
    final now = DateTime.now();
    return [
      Post(
        postId: 'off_stemborer',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Extension Officer',
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
        userName: 'Agridic Official',
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
}
