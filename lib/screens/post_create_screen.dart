import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../utils/app_colors.dart';

class PostCreateScreen extends StatefulWidget {
  const PostCreateScreen({super.key});

  @override
  State<PostCreateScreen> createState() => _PostCreateScreenState();
}

class _PostCreateScreenState extends State<PostCreateScreen> {
  String _postType = 'tweet'; // 'tweet' or 'report'
  String _activeMode = 'text'; // 'text', 'manual', 'visual'

  // Tweet fields
  final _tweetTextCtrl = TextEditingController();
  String _tweetImagePath = '';

  // Report fields
  final _rptTitleCtrl = TextEditingController();
  final _rptCropCtrl = TextEditingController();
  final _rptLocationCtrl = TextEditingController();

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
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentBlocks => _blocks[_activeMode]!;

  int _nextId() => ++_blockCounter;

  void _addBlock(String type, {int? afterId}) {
    final block = {
      'id': _nextId(),
      'type': type,
      'ctrl': TextEditingController(),
    };
    setState(() {
      final blocks = _currentBlocks;
      if (afterId != null) {
        final idx = blocks.indexWhere((b) => b['id'] == afterId);
        blocks.insert(idx + 1, block);
      } else {
        blocks.add(block);
      }
    });
  }

  void _removeBlock(int id) {
    setState(() => _currentBlocks.removeWhere((b) => b['id'] == id));
  }

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

  Future<void> _pickTweetImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _tweetImagePath = file.path);
  }

  Future<void> _pickBlockImage(TextEditingController ctrl) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => ctrl.text = file.path);
  }

  (String, List<String>, List<String>) _blocksToText(List<Map<String, dynamic>> blocks) {
    final lines = <String>[];
    final images = <String>[];
    final steps = <String>[];
    int imgCounter = 0;

    for (final block in blocks) {
      final val = (block['ctrl'] as TextEditingController).text.trim();
      if (val.isEmpty) continue;
      final type = block['type'] as String;
      switch (type) {
        case 'heading':
          lines.add('## $val');
        case 'text':
          lines.add(val);
          lines.add('');
        case 'bullets':
          for (var line in val.split('\n')) {
            line = line.trim();
            if (line.isNotEmpty) {
              if (!line.startsWith('- ')) line = '- $line';
              lines.add(line);
              steps.add(line.startsWith('- ') ? line.substring(2) : line);
            }
          }
          lines.add('');
        case 'image':
          imgCounter++;
          images.add(val);
          lines.add('![$imgCounter]');
          lines.add('');
      }
    }
    return (lines.join('\n'), images, steps);
  }

  void _submit() {
    final state = context.read<AppState>();

    if (_postType == 'tweet') {
      if (_tweetTextCtrl.text.trim().isEmpty) {
        _showError('Please enter some text.');
        return;
      }
      final newPost = Post(
        postId: 'new_${DateTime.now().millisecondsSinceEpoch}',
        isOfficial: false,
        userRole: 'farmer',
        userName: 'You',
        content: PostContent(
          textShort: _tweetTextCtrl.text.trim(),
          imageLow: _tweetImagePath,
          imageHigh: _tweetImagePath,
        ),
        timestamp: DateTime.now(),
        location: state.currentLocation,
      );
      state.addPost(newPost);
    } else {
      if (_rptTitleCtrl.text.trim().isEmpty) {
        _showError('Please enter a headline.');
        return;
      }
      final headline = _rptTitleCtrl.text.trim();
      final crop = _rptCropCtrl.text.trim();
      final loc = _rptLocationCtrl.text.trim();

      final shortParts = [headline];
      if (crop.isNotEmpty) shortParts.add('[$crop]');
      if (loc.isNotEmpty) shortParts.add('— $loc');

      final activeBlocks = _blocks[_activeMode]!;
      final (tf, imgs, steps) = _blocksToText(activeBlocks);

      final newPost = Post(
        postId: 'new_${DateTime.now().millisecondsSinceEpoch}',
        isOfficial: true,
        userRole: 'expert',
        userName: 'You (Expert)',
        content: PostContent(
          textShort: shortParts.join(' '),
          textFull: tf,
          steps: steps,
          images: imgs,
        ),
        timestamp: DateTime.now(),
        isVerified: true,
        location: state.currentLocation,
        viewMode: _activeMode,
        dictCrop: crop,
      );
      state.addPost(newPost);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('${_postType == 'tweet' ? 'Tweet' : 'Report'} posted!',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
      backgroundColor: AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('New Post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    // Type toggle
                    SegmentedButton<String>(
                      selected: {_postType},
                      onSelectionChanged: (s) => setState(() => _postType = s.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) return Colors.white;
                          return Colors.transparent;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) return AppColors.primary;
                          return Colors.white;
                        }),
                        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white54)),
                      ),
                      segments: const [
                        ButtonSegment(value: 'tweet', label: Text('Tweet')),
                        ButtonSegment(value: 'report', label: Text('Report')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _postType == 'tweet' ? _buildTweetForm() : _buildReportForm(),
            ),
          ),
          // Submit button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Submit', style: TextStyle(fontSize: 16)),
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
        const Row(
          children: [
            Icon(Icons.edit_note, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Compose Tweet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tweetTextCtrl,
          maxLines: 8,
          minLines: 3,
          decoration: InputDecoration(
            hintText: "What's happening in your farm?",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickTweetImage,
          icon: const Icon(Icons.add_a_photo_outlined, size: 16),
          label: const Text('Add Photo', style: TextStyle(fontSize: 12)),
        ),
        if (_tweetImagePath.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.image, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_tweetImagePath, style: const TextStyle(fontSize: 12, color: AppColors.primary))),
                TextButton(
                  onPressed: () => setState(() => _tweetImagePath = ''),
                  child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReportForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.verified_user, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Create Official Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        _buildField(_rptTitleCtrl, 'Report headline (shown on timeline)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildField(_rptCropCtrl, 'Crop: e.g. Maize, Tomato...')),
            const SizedBox(width: 8),
            Expanded(child: _buildField(_rptLocationCtrl, 'Location: e.g. Gatanga...')),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        const Text('Create content for each view mode:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        // Mode tabs
        Row(
          children: [
            _buildModeTab('text', 'Text Only', Icons.text_snippet_outlined),
            const SizedBox(width: 4),
            _buildModeTab('manual', 'Text+Image', Icons.auto_awesome_outlined),
            const SizedBox(width: 4),
            _buildModeTab('visual', 'Image Main', Icons.image_outlined),
          ],
        ),
        const SizedBox(height: 12),
        // Block editor
        _buildBlockEditor(),
      ],
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
          child: Column(
            children: [
              Icon(icon, size: 16, color: isActive ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockEditor() {
    final blocks = _currentBlocks;
    final typeColors = {
      'heading': AppColors.primary,
      'text': AppColors.divider,
      'bullets': AppColors.accent,
      'image': const Color(0xFF90CAF9),
    };

    return Column(
      children: [
        _buildInsertRow(null),
        ...blocks.map((block) {
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
                    Row(
                      children: [
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
                      ],
                    ),
                    if (type == 'image')
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              decoration: InputDecoration(
                                hintText: 'Describe what this image shows...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.folder_open_outlined, color: AppColors.primary),
                            onPressed: () => _pickBlockImage(ctrl),
                          ),
                        ],
                      )
                    else
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

  IconData _blockIcon(String type) {
    return switch (type) {
      'heading' => Icons.title,
      'text' => Icons.text_fields,
      'bullets' => Icons.format_list_bulleted,
      'image' => Icons.image_outlined,
      _ => Icons.square,
    };
  }

  String _blockHint(String type) {
    return switch (type) {
      'heading' => 'Section heading...',
      'text' => 'Write paragraph text...',
      'bullets' => 'One bullet point per line...',
      _ => '',
    };
  }
}
