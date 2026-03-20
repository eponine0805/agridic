import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  String _postType = 'tweet';
  String _activeMode = 'text';
  bool _submitting = false;

  // Location
  (double, double)? _selectedLocation;

  // Tweet fields
  final _tweetTextCtrl = TextEditingController();
  XFile? _tweetImageFile;

  // Report fields
  final _rptTitleCtrl = TextEditingController();
  final _rptCropCtrl = TextEditingController();
  final _rptLocationCtrl = TextEditingController();

  // Shared tags
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();

  // Block lists per mode
  final Map<String, List<Map<String, dynamic>>> _blocks = {
    'text': [],
    'manual': [],
    'visual': [],
  };
  int _blockCounter = 0;

  @override
  void dispose() {
    _tweetTextCtrl.dispose();
    _rptTitleCtrl.dispose();
    _rptCropCtrl.dispose();
    _rptLocationCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // ─── Tags ──────────────────────────────────────────────────────────────

  void _addTag() {
    final tag = _tagCtrl.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagCtrl.clear();
      });
    }
  }

  // ─── Blocks ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> get _currentBlocks => _blocks[_activeMode]!;
  int _nextId() => ++_blockCounter;

  void _addBlock(String type, {int? afterId}) {
    final block = {'id': _nextId(), 'type': type, 'ctrl': TextEditingController()};
    setState(() {
      final blocks = _currentBlocks;
      if (afterId != null) {
        blocks.insert(blocks.indexWhere((b) => b['id'] == afterId) + 1, block);
      } else {
        blocks.add(block);
      }
    });
  }

  void _removeBlock(int id) =>
      setState(() => _currentBlocks.removeWhere((b) => b['id'] == id));

  void _moveBlock(int id, int direction) {
    final blocks = _currentBlocks;
    final idx = blocks.indexWhere((b) => b['id'] == id);
    final newIdx = idx + direction;
    if (newIdx >= 0 && newIdx < blocks.length) {
      setState(() {
        final temp = blocks[idx];
        blocks[idx] = blocks[newIdx];
        blocks[newIdx] = temp;
      });
    }
  }

  // ─── Image ─────────────────────────────────────────────────────────────

  Future<void> _pickTweetImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _tweetImageFile = file);
  }

  Future<void> _pickBlockImage(int blockId) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        final block = _currentBlocks.firstWhere((b) => b['id'] == blockId);
        block['file'] = file;
        block['ctrl'].text = file.name;
      });
    }
  }

  // ─── Blocks → text ─────────────────────────────────────────────────────

  (String, List<String>, List<String>) _blocksToText(List<Map<String, dynamic>> blocks) {
    final lines = <String>[];
    final images = <String>[];
    final steps = <String>[];
    int imgCounter = 0;

    for (final block in blocks) {
      final val = (block['ctrl'] as TextEditingController).text.trim();
      if (val.isEmpty) continue;
      switch (block['type'] as String) {
        case 'heading':
          lines.add('## $val');
        case 'text':
          lines..add(val)..add('');
        case 'bullets':
          for (var line in val.split('\n')) {
            line = line.trim();
            if (line.isNotEmpty) lines.add(line.startsWith('- ') ? line : '- $line');
          }
          lines.add('');
        case 'action_plan':
          for (var line in val.split('\n')) {
            line = line.trim();
            if (line.isNotEmpty) steps.add(line);
          }
          lines.add('');
        case 'image':
          imgCounter++;
          images.add(val);
          lines..add('![$imgCounter]')..add('');
      }
    }
    return (lines.join('\n'), images, steps);
  }

  // ─── Location ──────────────────────────────────────────────────────────

  (double, double)? get _resolvedLocation {
    if (_selectedLocation != null) return _selectedLocation;
    final state = context.read<AppState>();
    return state.locationReady ? state.currentLocation : null;
  }

  Future<void> _openLocationPicker() async {
    final state = context.read<AppState>();
    final base = _selectedLocation ?? (state.locationReady ? state.currentLocation : null);
    final initial = base != null ? LatLng(base.$1, base.$2) : const LatLng(-0.95, 36.87);
    final gps = state.locationReady
        ? LatLng(state.currentLocation.$1, state.currentLocation.$2)
        : null;

    final result = await Navigator.push<(double, double)>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationPickerScreen(initialLocation: initial, currentGps: gps),
      ),
    );
    if (result != null) setState(() => _selectedLocation = result);
  }

  // ─── Submit ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    final state = context.read<AppState>();
    final userPrefs = context.read<UserPrefs>();
    final postId = 'new_${DateTime.now().millisecondsSinceEpoch}';

    if (_postType == 'tweet') {
      if (_tweetTextCtrl.text.trim().isEmpty) { _showError('Please enter some text.'); return; }
      setState(() => _submitting = true);

      String imageLow = '', imageHigh = '';
      if (_tweetImageFile != null && state.isOnline) {
        try {
          final urls = await FirebaseService.uploadImage(postId, _tweetImageFile!);
          imageLow = urls.low;
          imageHigh = urls.high;
        } catch (e) {
          setState(() => _submitting = false);
          if (!mounted) return;
          _showError('Image upload failed: $e');
          return;
        }
      }

      await state.addPost(Post(
        postId: postId,
        userId: userPrefs.userId,
        isOfficial: false,
        userRole: userPrefs.userRole,
        userName: userPrefs.userName,
        content: PostContent(
          textShort: _tweetTextCtrl.text.trim(),
          imageLow: imageLow,
          imageHigh: imageHigh,
        ),
        timestamp: DateTime.now(),
        location: _resolvedLocation,
        dictTags: _tags,
      ));
    } else {
      if (_rptTitleCtrl.text.trim().isEmpty) { _showError('Please enter a headline.'); return; }
      setState(() => _submitting = true);

      final headline = _rptTitleCtrl.text.trim();
      final crop = _rptCropCtrl.text.trim();
      final loc = _rptLocationCtrl.text.trim();
      final shortParts = [headline];
      if (crop.isNotEmpty) shortParts.add('[$crop]');
      if (loc.isNotEmpty) shortParts.add('— $loc');

      // 全モードの画像をアップロード（オンライン時のみ）
      if (state.isOnline) {
        for (final mode in ['text', 'manual', 'visual']) {
          for (final block in _blocks[mode]!) {
            if (block['type'] == 'image' && block['file'] != null) {
              try {
                final urls = await FirebaseService.uploadImage(
                    '${postId}_${mode}_img_${block['id']}', block['file'] as XFile);
                (block['ctrl'] as TextEditingController).text =
                    urls.high.isNotEmpty ? urls.high : urls.low;
              } catch (e) {
                setState(() => _submitting = false);
                if (!mounted) return;
                _showError('Image processing failed: $e');
                return;
              }
            }
          }
        }
      }

      // 各モードのブロックをテキストに変換し、それぞれのフィールドに保存
      String textFull = '', textFullManual = '', textFullVisual = '';
      List<String> imgs = [], steps = [];

      if (_blocks['text']!.isNotEmpty) {
        final (tf, _, st) = _blocksToText(_blocks['text']!);
        textFull = tf;
        if (st.isNotEmpty) steps = st;
      }
      if (_blocks['manual']!.isNotEmpty) {
        final (tf, im, st) = _blocksToText(_blocks['manual']!);
        textFullManual = tf;
        if (im.isNotEmpty) imgs = im;
        if (st.isNotEmpty && steps.isEmpty) steps = st;
      }
      if (_blocks['visual']!.isNotEmpty) {
        final (tf, im, st) = _blocksToText(_blocks['visual']!);
        textFullVisual = tf;
        if (im.isNotEmpty && imgs.isEmpty) imgs = im;
        if (st.isNotEmpty && steps.isEmpty) steps = st;
      }

      await state.addPost(Post(
        postId: postId,
        userId: userPrefs.userId,
        isOfficial: userPrefs.isExpert,
        userRole: userPrefs.userRole,
        userName: userPrefs.userName,
        content: PostContent(
          textShort: shortParts.join(' '),
          textFull: textFull,
          textFullManual: textFullManual,
          textFullVisual: textFullVisual,
          steps: steps,
          images: imgs,
        ),
        timestamp: DateTime.now(),
        isVerified: true,
        location: _resolvedLocation,
        viewMode: _activeMode,
        dictCrop: crop,
        dictTags: _tags,
      ));
    }

    setState(() => _submitting = false);
    if (!mounted) return;
    Navigator.pop(context);
    final isOnline = state.isOnline;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isOnline ? Icons.check_circle : Icons.cloud_queue,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          isOnline
              ? (_postType == 'tweet' ? 'Post shared!' : 'Report published!')
              : 'Saved offline — will post when connected',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ]),
      backgroundColor: isOnline ? AppColors.primary : AppColors.accent,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showError(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('New post',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    SegmentedButton<String>(
                      selected: {_postType},
                      onSelectionChanged: (s) => setState(() => _postType = s.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected) ? Colors.white : Colors.transparent),
                        foregroundColor: WidgetStateProperty.resolveWith((s) =>
                            s.contains(WidgetState.selected) ? AppColors.primary : Colors.white),
                        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white54)),
                      ),
                      segments: const [
                        ButtonSegment(value: 'tweet', label: Text('Post')),
                        ButtonSegment(value: 'report', label: Text('Report')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _postType == 'tweet' ? _buildTweetForm() : _buildReportForm(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Publish', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTweetForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.edit_note, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Write a post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _tweetTextCtrl,
          maxLines: 8,
          minLines: 3,
          decoration: InputDecoration(
            hintText: "What's happening on your farm?",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickTweetImage,
          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
          label: const Text('Add photo', style: TextStyle(fontSize: 12)),
        ),
        // Image preview
        if (_tweetImageFile != null) ...[
          const SizedBox(height: 8),
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_tweetImageFile!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6, right: 6,
                child: GestureDetector(
                  onTap: () => setState(() => _tweetImageFile = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        _buildLocationRow(),
        const SizedBox(height: 12),
        _buildTagsInput(),
      ],
    );
  }

  Widget _buildReportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.verified_user, size: 20, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Create Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const SizedBox(height: 12),
        _buildField(_rptTitleCtrl, 'Report headline (shown on timeline)'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildField(_rptCropCtrl, 'Crop: e.g. Maize, Tomato…')),
          const SizedBox(width: 8),
          Expanded(child: _buildField(_rptLocationCtrl, 'Location name: e.g. Nakuru…')),
        ]),
        const SizedBox(height: 8),
        _buildLocationRow(),
        const SizedBox(height: 8),
        _buildTagsInput(),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        const Text('Choose report format:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(children: [
          _buildModeTab('text', 'Text only', Icons.text_snippet_outlined),
          const SizedBox(width: 4),
          _buildModeTab('manual', 'Text + Images', Icons.auto_awesome_outlined),
          const SizedBox(width: 4),
          _buildModeTab('visual', 'Image-based', Icons.image_outlined),
        ]),
        const SizedBox(height: 12),
        _buildBlockEditor(),
      ],
    );
  }

  Widget _buildTagsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [
          Icon(Icons.label_outline, size: 16, color: AppColors.primary),
          SizedBox(width: 4),
          Text('Keywords', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _tags.map((t) => Chip(
              label: Text(t, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _tags.remove(t)),
              deleteIconColor: AppColors.textSecondary,
              backgroundColor: AppColors.modeActive,
              side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            )).toList(),
          ),
          const SizedBox(height: 6),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              controller: _tagCtrl,
              decoration: InputDecoration(
                hintText: 'Add keyword + Enter  (e.g. maize, stem borer…)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintStyle: const TextStyle(fontSize: 12),
                isDense: true,
              ),
              onSubmitted: (_) => _addTag(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
            onPressed: _addTag,
            visualDensity: VisualDensity.compact,
          ),
        ]),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final loc = _selectedLocation ?? (state.locationReady ? state.currentLocation : null);
        return Row(children: [
          const Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          if (state.isDetectingLocation)
            const Text('Getting location…',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
          else if (loc != null)
            Text(
              '📍 ${loc.$1.toStringAsFixed(4)}, ${loc.$2.toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            )
          else
            const Text('Location unavailable',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const Spacer(),
          if (!state.isDetectingLocation)
            TextButton.icon(
              onPressed: _openLocationPicker,
              icon: const Icon(Icons.edit_location_outlined, size: 14),
              label: const Text('Adjust', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ]);
      },
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _buildModeTab(String mode, String label, IconData icon) {
    final isActive = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.modeActive : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              bottom: BorderSide(color: isActive ? AppColors.primary : AppColors.divider, width: isActive ? 2 : 1),
              top: BorderSide(color: AppColors.divider),
              left: BorderSide(color: AppColors.divider),
              right: BorderSide(color: AppColors.divider),
            ),
          ),
          child: Column(children: [
            Icon(icon, size: 16, color: isActive ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center),
          ]),
        ),
      ),
    );
  }

  Widget _buildBlockEditor() {
    final typeColors = {
      'heading': AppColors.primary,
      'text': AppColors.divider,
      'bullets': AppColors.accent,
      'action_plan': AppColors.primaryDark,
      'image': const Color(0xFF90CAF9),
    };

    return Column(
      children: [
        _buildInsertRow(null),
        ..._currentBlocks.map((block) {
          final id = block['id'] as int;
          final type = block['type'] as String;
          final ctrl = block['ctrl'] as TextEditingController;
          final borderColor = typeColors[type] ?? AppColors.divider;

          return Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor, width: 3),
                    top: const BorderSide(color: AppColors.divider, width: 0.5),
                    right: const BorderSide(color: AppColors.divider, width: 0.5),
                    bottom: const BorderSide(color: AppColors.divider, width: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  children: [
                    Row(children: [
                      Icon(_blockIcon(type), size: 14, color: borderColor),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 14),
                        onPressed: () => _moveBlock(id, -1),
                        color: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_downward, size: 14),
                        onPressed: () => _moveBlock(id, 1),
                        color: AppColors.textSecondary,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        onPressed: () => _removeBlock(id),
                        color: AppColors.danger,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                    ]),
                    if (type == 'image') ...[
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Select an image…',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open_outlined, color: AppColors.primary),
                          onPressed: () => _pickBlockImage(id),
                        ),
                      ]),
                      // Image preview
                      if (block['file'] != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File((block['file'] as XFile).path),
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ] else
                      TextField(
                        controller: ctrl,
                        maxLines: type == 'heading' ? 1 : 6,
                        minLines: type == 'heading' ? 1 : 2,
                        style: type == 'heading'
                            ? const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)
                            : const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _blockHint(type),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                  ],
                ),
              ),
              _buildInsertRow(id),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildInsertRow(int? afterId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _insertBtn(Icons.title, 'Heading', () => _addBlock('heading', afterId: afterId)),
          _insertBtn(Icons.text_fields, 'Text', () => _addBlock('text', afterId: afterId)),
          _insertBtn(Icons.format_list_bulleted, 'Bullets', () => _addBlock('bullets', afterId: afterId)),
          _insertBtn(Icons.checklist_rtl, 'Action Plan', () => _addBlock('action_plan', afterId: afterId)),
          // テキストモードでは画像ブロック不可
          if (_activeMode != 'text')
            _insertBtn(Icons.image_outlined, 'Image', () => _addBlock('image', afterId: afterId)),
        ],
      ),
    );
  }

  Widget _insertBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 12, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  IconData _blockIcon(String type) => switch (type) {
    'heading' => Icons.title,
    'text' => Icons.text_fields,
    'bullets' => Icons.format_list_bulleted,
    'action_plan' => Icons.checklist_rtl,
    'image' => Icons.image_outlined,
    _ => Icons.square,
  };

  String _blockHint(String type) => switch (type) {
    'heading' => 'Section heading…',
    'text' => 'Write paragraph text…',
    'bullets' => 'One bullet point per line…',
    'action_plan' => 'One action step per line…',
    _ => '',
  };
}

// ─── Location Picker ───────────────────────────────────────────────────────

class _LocationPickerScreen extends StatefulWidget {
  final LatLng initialLocation;
  final LatLng? currentGps; // 青い点の位置
  const _LocationPickerScreen({required this.initialLocation, this.currentGps});

  @override
  State<_LocationPickerScreen> createState() => __LocationPickerScreenState();
}

class __LocationPickerScreenState extends State<_LocationPickerScreen> {
  late LatLng _center;

  @override
  void initState() {
    super.initState();
    _center = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Adjust location',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, (_center.latitude, _center.longitude)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: widget.initialLocation,
                    initialZoom: 13.0,
                    onMapEvent: (evt) => setState(() => _center = evt.camera.center),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.agridic.app',
                      maxZoom: 19,
                    ),
                    // 現在地の青い点
                    if (widget.currentGps != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: widget.currentGps!,
                          width: 24,
                          height: 24,
                          child: const _CurrentLocationDot(),
                        ),
                      ]),
                  ],
                ),
                // 中心ピン（ここに投稿される）
                const IgnorePointer(
                  child: Icon(Icons.location_on, color: AppColors.primary, size: 40),
                ),
                // 座標表示
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Google Maps スタイルの現在地ドット
class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF4285F4).withOpacity(0.18),
          ),
        ),
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 3, spreadRadius: 1),
            ],
          ),
        ),
        Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4285F4),
          ),
        ),
      ],
    );
  }
}
