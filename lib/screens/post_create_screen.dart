import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
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
  String _postType = 'tweet'; // 'tweet' or 'report'
  String _activeMode = 'text'; // 'text', 'manual', 'visual'

  bool _submitting = false;

  // Location
  bool _locationAuto = true;
  (double, double)? _autoLocation;
  bool _gettingLocation = false;

  // Tweet fields
  final _tweetTextCtrl = TextEditingController();
  XFile? _tweetImageFile;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
  }

  @override
  void dispose() {
    _tweetTextCtrl.dispose();
    _rptTitleCtrl.dispose();
    _rptCropCtrl.dispose();
    _rptLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _detectLocation() async {
    if (!_locationAuto) return;
    setState(() => _gettingLocation = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _gettingLocation = false;
          _locationAuto = false;
        });
        _showError('Location permission denied. Enter location manually.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() {
          _autoLocation = (pos.latitude, pos.longitude);
          _gettingLocation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
          _autoLocation = null;
        });
      }
    }
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
    if (file != null) setState(() => _tweetImageFile = file);
  }

  Future<void> _pickBlockImage(int blockId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        final block = _currentBlocks.firstWhere((b) => b['id'] == blockId);
        block['file'] = file;
        block['ctrl'].text = file.name;
      });
    }
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

  (double, double)? get _resolvedLocation {
    final state = context.read<AppState>();
    if (_locationAuto) {
      return _autoLocation ?? state.currentLocation;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final state = context.read<AppState>();
    final userPrefs = context.read<UserPrefs>();
    final postId = 'new_${DateTime.now().millisecondsSinceEpoch}';

    if (_postType == 'tweet') {
      if (_tweetTextCtrl.text.trim().isEmpty) {
        _showError('Please enter some text.');
        return;
      }
      setState(() => _submitting = true);

      String imageLow = '';
      String imageHigh = '';
      if (_tweetImageFile != null) {
        try {
          final urls =
              await FirebaseService.uploadImage(postId, _tweetImageFile!);
          imageLow = urls.low;
          imageHigh = urls.high;
        } catch (_) {}
      }

      final newPost = Post(
        postId: postId,
        isOfficial: false,
        userRole: 'farmer',
        userName: userPrefs.userName,
        content: PostContent(
          textShort: _tweetTextCtrl.text.trim(),
          imageLow: imageLow,
          imageHigh: imageHigh,
        ),
        timestamp: DateTime.now(),
        location: _resolvedLocation,
      );
      await state.addPost(newPost);
    } else {
      if (_rptTitleCtrl.text.trim().isEmpty) {
        _showError('Please enter a headline.');
        return;
      }
      setState(() => _submitting = true);

      final headline = _rptTitleCtrl.text.trim();
      final crop = _rptCropCtrl.text.trim();
      final loc = _rptLocationCtrl.text.trim();

      final shortParts = [headline];
      if (crop.isNotEmpty) shortParts.add('[$crop]');
      if (loc.isNotEmpty) shortParts.add('— $loc');

      final activeBlocks = _blocks[_activeMode]!;

      for (final block in activeBlocks) {
        if (block['type'] == 'image' && block['file'] != null) {
          try {
            final imgPostId = '${postId}_img_${block['id']}';
            final urls = await FirebaseService.uploadImage(
                imgPostId, block['file'] as XFile);
            (block['ctrl'] as TextEditingController).text = urls.high;
          } catch (_) {}
        }
      }

      final (tf, imgs, steps) = _blocksToText(activeBlocks);

      final newPost = Post(
        postId: postId,
        isOfficial: true,
        userRole: 'expert',
        userName: userPrefs.userName,
        content: PostContent(
          textShort: shortParts.join(' '),
          textFull: tf,
          steps: steps,
          images: imgs,
        ),
        timestamp: DateTime.now(),
        isVerified: true,
        location: _resolvedLocation,
        viewMode: _activeMode,
        dictCrop: crop,
      );
      await state.addPost(newPost);
    }

    setState(() => _submitting = false);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            _postType == 'tweet' ? 'Post shared!' : 'Report published!',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500),
          ),
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
                        const Text('New post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        ButtonSegment(value: 'tweet', label: Text('Post')),
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
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
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
        const Row(
          children: [
            Icon(Icons.edit_note, size: 20, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Write a post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tweetTextCtrl,
          maxLines: 8,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'What\'s happening on your farm?',
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
        if (_tweetImageFile != null) ...[
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
                Expanded(child: Text(_tweetImageFile!.name, style: const TextStyle(fontSize: 12, color: AppColors.primary))),
                TextButton(
                  onPressed: () => setState(() => _tweetImageFile = null),
                  child: const Text('Remove', style: TextStyle(color: AppColors.danger, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        _buildLocationSelector(),
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
            Text('Create Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 12),
        _buildField(_rptTitleCtrl, 'Report headline (shown on timeline)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildField(_rptCropCtrl, 'Crop: e.g. Maize, Tomato…')),
            const SizedBox(width: 8),
            Expanded(child: _buildField(_rptLocationCtrl, 'Location name: e.g. Nakuru…')),
          ],
        ),
        const SizedBox(height: 8),
        _buildLocationSelector(),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.divider),
        const SizedBox(height: 8),
        const Text('Choose report format:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        // Mode tabs
        Row(
          children: [
            _buildModeTab('text', 'Text only', Icons.text_snippet_outlined),
            const SizedBox(width: 4),
            _buildModeTab('manual', 'Text + Images', Icons.auto_awesome_outlined),
            const SizedBox(width: 4),
            _buildModeTab('visual', 'Image-based', Icons.image_outlined),
          ],
        ),
        const SizedBox(height: 12),
        // Block editor
        _buildBlockEditor(),
      ],
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Text('Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _locationAuto = true);
                  _detectLocation();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: _locationAuto ? AppColors.modeActive : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _locationAuto ? AppColors.primary : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed, size: 18,
                          color: _locationAuto ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(height: 2),
                      Text('Auto-detect',
                          style: TextStyle(
                              fontSize: 11,
                              color: _locationAuto ? AppColors.primary : AppColors.textSecondary)),
                      if (_locationAuto && _gettingLocation) ...[
                        const SizedBox(height: 4),
                        const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(),
                        ),
                      ] else if (_locationAuto && _autoLocation != null) ...[
                        const SizedBox(height: 2),
                        Text('📍 GPS ready',
                            style: TextStyle(fontSize: 9, color: AppColors.primary)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _locationAuto = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: !_locationAuto ? AppColors.modeActive : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: !_locationAuto ? AppColors.primary : AppColors.divider,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_location_outlined, size: 18,
                          color: !_locationAuto ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(height: 2),
                      Text('No GPS',
                          style: TextStyle(
                              fontSize: 11,
                              color: !_locationAuto ? AppColors.primary : AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
      'heading' => 'Section heading…',
      'text' => 'Write paragraph text…',
      'bullets' => 'One bullet point per line…',
      _ => '',
    };
  }
}
