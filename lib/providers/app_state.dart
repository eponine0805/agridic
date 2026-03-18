import 'package:flutter/foundation.dart';
import '../models/post.dart';

class AppState extends ChangeNotifier {
  String searchQuery = '';
  (double, double) currentLocation = (-0.95, 36.87);

  final List<Post> _posts = _buildDummyPosts();

  List<Post> get posts => _posts;

  List<Post> get visiblePosts => _posts.where((p) => !p.isHidden).toList();

  List<Post> get officialPosts =>
      visiblePosts.where((p) => p.isOfficial && p.dictCrop.isNotEmpty).toList();

  List<Post> filteredPosts(String query) {
    if (query.isEmpty) {
      final all = visiblePosts.toList();
      all.sort((a, b) => (b.timestamp ?? DateTime(0)).compareTo(a.timestamp ?? DateTime(0)));
      return all;
    }
    final q = query.toLowerCase();
    return visiblePosts.where((p) =>
      p.content.textShort.toLowerCase().contains(q) ||
      p.content.textFull.toLowerCase().contains(q) ||
      p.userName.toLowerCase().contains(q) ||
      p.dictTags.any((t) => t.toLowerCase().contains(q))
    ).toList();
  }

  void reportPost(Post post) {
    post.reports++;
    if (post.reports >= 3) {
      post.isHidden = true;
    }
    notifyListeners();
  }

  void addPost(Post post) {
    _posts.insert(0, post);
    notifyListeners();
  }

  String formatTime(DateTime? ts) {
    if (ts == null) return '';
    final delta = DateTime.now().difference(ts);
    final seconds = delta.inSeconds;
    if (seconds < 60) return 'now';
    if (seconds < 3600) return '${delta.inMinutes}m';
    if (seconds < 86400) return '${delta.inHours}h';
    return '${delta.inDays}d';
  }

  static List<Post> _buildDummyPosts() {
    final now = DateTime.now();
    return [
      Post(
        postId: 'off_stemborer',
        isOfficial: true,
        userRole: 'expert',
        userName: 'Gatanga Agric. Office',
        content: const PostContent(
          textShort: 'Maize Stem Borer Alert & Control [Maize] — Gatanga',
          textFull: '## Maize Stem Borer — Alert & Control\n'
              '### Gatanga sub-county\n'
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
              'Contact Gatanga Agriculture Office for subsidised pesticides.',
          steps: [
            'IDENTIFY: Look for small holes on leaves and sawdust-like frass at the whorl. Pull damaged leaves to check for larvae.',
            'CULTURAL CONTROL: Remove and destroy crop residues after harvest. Rotate with beans or potatoes.',
            'BIOLOGICAL CONTROL (Push-Pull): Intercrop with Desmodium + Napier grass border.',
            'CHEMICAL CONTROL (if severe): Apply Bulldock Star into the leaf whorl at 2–3 weeks. Re-apply after 14 days.',
            'MONITOR: Scout twice weekly during weeks 2–6. Escalate if >20% plants are damaged.',
            'REPORT: Photo damaged leaves and post to this app. Contact Gatanga Agric. Office.',
          ],
          imageLow: '🐛',
          images: ['🐛 stem-borer-damage.jpg', '🌿 push-pull-desmodium.jpg'],
        ),
        location: (-0.95, 36.87),
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
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
        userName: 'Gatanga Agric. Office',
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
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
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
          textShort: 'Fall Armyworm (FAW) outbreak confirmed [Maize] — Nakuru / spreading to Murang\'a',
          textFull: '## Fall Armyworm (FAW) Outbreak\n'
              '### Nakuru County — spreading to Murang\'a\n'
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
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
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
        timestamp: DateTime.now().subtract(const Duration(hours: 12)),
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
          textShort: 'My maize leaves have small holes and there is sawdust stuff in the whorl. Is this stem borer? Help!',
          imageLow: '🌽',
        ),
        location: (-0.96, 36.88),
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        distanceKm: 1.8,
      ),
      Post(
        postId: 'usr_002',
        isOfficial: false,
        userRole: 'expert',
        userName: 'John Kamau',
        content: const PostContent(
          textShort: 'Mary, that sounds like stem borer. Search \'stem borer\' on this app for the official guide. Apply Bulldock into the whorl ASAP.',
          imageLow: '👨‍🌾',
        ),
        location: (-0.95, 36.87),
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        isVerified: true,
        distanceKm: 1.5,
      ),
      Post(
        postId: 'usr_003',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Grace Njeri',
        content: const PostContent(
          textShort: 'Just planted H614 last week, rains are looking good. Anyone else planting maize in Gatanga?',
        ),
        location: (-0.94, 36.86),
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        distanceKm: 2.1,
      ),
      Post(
        postId: 'usr_004',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'Peter Mwangi',
        content: const PostContent(
          textShort: 'When is the best time to apply CAN fertilizer for maize? Plants are about knee height.',
        ),
        location: (-0.97, 36.89),
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        distanceKm: 2.5,
      ),
      Post(
        postId: 'usr_005',
        isOfficial: false,
        userRole: 'expert',
        userName: 'John Kamau',
        content: const PostContent(
          textShort: 'Peter, knee height is perfect for 2nd top dressing. 1 tbsp CAN per plant, 10cm from stem. Wait for rain first.',
          imageLow: '👨‍🌾',
        ),
        location: (-0.95, 36.87),
        timestamp: DateTime.now().subtract(const Duration(minutes: 50)),
        isVerified: true,
        distanceKm: 1.5,
      ),
    ];
  }
}
