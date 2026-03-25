import 'dart:async';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/post.dart';
import '../providers/app_state.dart';
import '../providers/user_prefs.dart';
import '../services/dict_local_service.dart';
import '../services/firebase_service.dart';
import '../services/offline_queue_service.dart';
import '../services/post_draft_service.dart';
import '../utils/app_colors.dart';
import '../widgets/rich_text_content.dart';

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
  late final FocusNode _tagFocusNode;
  List<String> _availableTags = [];

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
    _tagFocusNode = FocusNode();
    _loadAvailableTags();
    _checkAndRestoreDraft();
  }

  Future<void> _loadAvailableTags() async {
    final result = await DictLocalService.load();
    if (result.posts.isNotEmpty && mounted) {
      final tags = result.posts
          .expand((p) => p.dictTags)
          .toSet()
          .toList()
        ..sort();
      setState(() => _availableTags = tags);
    }
  }

  @override
  void dispose() {
    _tweetTextCtrl.dispose();
    _rptTitleCtrl.dispose();
    _rptCropCtrl.dispose();
    _rptLocationCtrl.dispose();
    _tagCtrl.dispose();
    _tagFocusNode.dispose();
    // Dispose all block TextEditingControllers
    for (final blocks in _blocks.values) {
      for (final block in blocks) {
        (block['ctrl'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  // ─── Draft ─────────────────────────────────────────────────────────────

  Future<void> _checkAndRestoreDraft() async {
    if (!await PostDraftService.hasDraft()) return;
    if (!mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore draft?'),
        content: const Text(
            'You have an unsaved draft. Would you like to continue where you left off?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (restore == true) {
      final draft = await PostDraftService.loadDraft();
      setState(() {
        if (draft['tweetText']!.isNotEmpty) {
          _tweetTextCtrl.text = draft['tweetText']!;
        }
        if (draft['reportTitle']!.isNotEmpty) {
          _postType = 'report';
          _rptTitleCtrl.text = draft['reportTitle']!;
          _rptCropCtrl.text = draft['reportCrop']!;
          _rptLocationCtrl.text = draft['reportLoc']!;
        }
      });
    } else {
      await PostDraftService.clearDraft();
    }
  }

  Future<void> _saveDraft() async {
    await PostDraftService.saveDraft(
      tweetText: _tweetTextCtrl.text,
      reportTitle: _rptTitleCtrl.text,
      reportCrop: _rptCropCtrl.text,
      reportLoc: _rptLocationCtrl.text,
    );
  }

  Future<void> _handleBack() async {
    await _saveDraft();
    if (mounted) Navigator.pop(context);
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

  void _addBlock(String type, {int? afterId, String? text}) {
    final block = {'id': _nextId(), 'type': type, 'ctrl': TextEditingController(text: text ?? '')};
    setState(() {
      final blocks = _currentBlocks;
      if (afterId != null) {
        blocks.insert(blocks.indexWhere((b) => b['id'] == afterId) + 1, block);
      } else {
        blocks.add(block);
      }
    });
  }

  void _toggleBlockType(int id) {
    setState(() {
      final block = _currentBlocks.firstWhere((b) => b['id'] == id);
      block['type'] = block['type'] == 'heading' ? 'text' : 'heading';
    });
  }

  void _removeBlock(int id) {
    final block = _currentBlocks.firstWhere((b) => b['id'] == id);
    (block['ctrl'] as TextEditingController).dispose();
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

  // ─── Image ─────────────────────────────────────────────────────────────

  static const _maxImageBytes = 10 * 1024 * 1024; // 10 MB

  /// Validates a file by checking its magic bytes (JPEG / PNG / GIF / WebP).
  static Future<bool> _isValidImageFile(XFile file) async {
    try {
      final bytes = await file.openRead(0, 12).expand((b) => b).toList();
      if (bytes.length < 4) return false;
      // JPEG
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
      // PNG
      if (bytes[0] == 0x89 && bytes[1] == 0x50 &&
          bytes[2] == 0x4E && bytes[3] == 0x47) return true;
      // GIF
      if (bytes[0] == 0x47 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x38) return true;
      // WebP: RIFF????WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 && bytes[1] == 0x49 &&
          bytes[2] == 0x46 && bytes[3] == 0x46 &&
          bytes[8] == 0x57 && bytes[9] == 0x45 &&
          bytes[10] == 0x42 && bytes[11] == 0x50) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _validateImage(XFile file) async {
    final size = await file.length();
    if (size > _maxImageBytes) {
      if (mounted) _showError('Image too large (max 10 MB)');
      return false;
    }
    if (!await _isValidImageFile(file)) {
      if (mounted) _showError('Unsupported file format — use JPEG, PNG, GIF, or WebP');
      return false;
    }
    return true;
  }

  Future<void> _pickTweetImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    if (!await _validateImage(file)) return;
    setState(() => _tweetImageFile = file);
  }

  Future<void> _pickBlockImage(int blockId) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    if (!await _validateImage(file)) return;
    setState(() {
      final block = _currentBlocks.firstWhere((b) => b['id'] == blockId);
      block['file'] = file;
      block['ctrl'].text = file.name;
    });
  }

  // ─── Excel import ──────────────────────────────────────────────────────

  Future<void> _importFromExcel() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );
    } catch (_) {
      if (mounted) _showError('Could not open file picker');
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) {
      if (mounted) _showError('Could not read the selected file');
      return;
    }
    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        if (mounted) _showError('No sheets found in the Excel file');
        return;
      }
      final sheet = excel.tables.values.first;
      int added = 0;
      for (final row in sheet.rows) {
        if (row.isEmpty) continue;
        final cell = row.first;
        if (cell?.value == null) continue;
        final text = cell!.value.toString().trim();
        if (text.isEmpty) continue;
        _addBlock('text', text: text);
        added++;
      }
      if (!mounted) return;
      if (added == 0) {
        _showError('No importable data found in the file');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imported $added row${added == 1 ? '' : 's'}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) _showError('Failed to read Excel file: $e');
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

    // If location was permanently denied, guide the user to system settings
    if (state.locationPermissionDeniedForever) {
      await _showLocationSettingsDialog();
      return;
    }

    // If location is not yet obtained, attempt detection first
    if (!state.locationReady && !state.isDetectingLocation) {
      await state.detectLocation();
      if (!mounted) return;
      if (state.locationPermissionDeniedForever) {
        await _showLocationSettingsDialog();
        return;
      }
    }

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

  Future<void> _showLocationSettingsDialog() async {
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location access required'),
        content: const Text(
            'Location permission has been permanently denied. '
            'Open Settings to allow location access for this app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (open == true) unawaited(Geolocator.openAppSettings());
  }

  // ─── Preview ───────────────────────────────────────────────────────────

  /// Builds preview widgets by rendering blocks directly (identical to the actual report view).
  List<Widget> _buildBlocksPreviewWidgets(List<Map<String, dynamic>> blocks) {
    final widgets = <Widget>[];
    final steps = <String>[];

    for (final block in blocks) {
      final type = block['type'] as String;
      final val = (block['ctrl'] as TextEditingController).text.trim();
      final file = block['file'] as XFile?;

      switch (type) {
        case 'heading':
          if (val.isEmpty) continue;
          widgets.add(const SizedBox(height: 4));
          widgets.add(Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.primaryLight, width: 2)),
            ),
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(val,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
          ));
        case 'text':
          if (val.isEmpty) continue;
          widgets.add(Text(val,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)));
          widgets.add(const SizedBox(height: 4));
        case 'bullets':
          for (var line in val.split('\n')) {
            line = line.trim();
            if (line.isEmpty) continue;
            final text = line.startsWith('- ') ? line.substring(2) : line;
            widgets.add(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                Expanded(child: Text(text,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
              ],
            ));
          }
          widgets.add(const SizedBox(height: 4));
        case 'action_plan':
          for (var line in val.split('\n')) {
            line = line.trim();
            if (line.isNotEmpty) steps.add(line);
          }
        case 'image':
          if (file != null) {
            widgets.add(Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(file.path),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ));
          } else {
            widgets.add(Container(
              height: 60,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.modeActive,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.image_outlined, color: AppColors.primary, size: 24),
              ),
            ));
          }
      }
    }

    if (steps.isNotEmpty) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(StepsCard(steps: steps));
    }

    return widgets;
  }

  void _showPreview() {
    final title = _rptTitleCtrl.text.trim();
    if (title.isEmpty) {
      _showError('Please add a title before previewing');
      return;
    }

    // Preview the currently active mode's blocks
    final previewBlocks = _blocks[_activeMode]!;
    final previewWidgets = _buildBlocksPreviewWidgets(previewBlocks);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.preview_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Preview',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header card (same style as actual post card)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: const Border(
                            left: BorderSide(color: AppColors.primary, width: 3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            if (_rptCropCtrl.text.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.eco, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(_rptCropCtrl.text.trim(),
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.primary)),
                              ]),
                            ],
                            if (_tags.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: _tags.map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.modeActive,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: AppColors.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(t,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primaryDark)),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Render blocks directly (identical to the actual post view)
                      if (previewWidgets.isNotEmpty)
                        ...previewWidgets
                      else
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No content yet — add some blocks',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 14)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Submit ────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_submitting) return;
    try {
      await _submitInternal();
    } catch (e) {
      setState(() => _submitting = false);
      if (mounted) _showError('Something went wrong: $e');
    }
  }

  Future<void> _submitInternal() async {
    final state = context.read<AppState>();
    final userPrefs = context.read<UserPrefs>();
    final postId = 'new_${DateTime.now().millisecondsSinceEpoch}';

    if (_postType == 'tweet') {
      if (_tweetTextCtrl.text.trim().isEmpty) { _showError('Please enter some text.'); return; }
      setState(() => _submitting = true);

      String imageLow = '', imageHigh = '';
      // Upload immediately when online; pass local path to the queue when offline
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

      final queued = await state.addPost(
        Post(
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
          postType: 'tweet',
          avatarBase64: userPrefs.avatarBase64,
        ),
        // Offline: pass local path — automatically uploaded when connectivity is restored
        localTweetImagePath:
            (!state.isOnline && _tweetImageFile != null) ? _tweetImageFile!.path : null,
      );
      if (queued == null) {
        setState(() => _submitting = false);
        if (mounted) _showError('Offline queue is full (max ${OfflineQueueService.maxQueueSize}). Please retry when online.');
        return;
      }
    } else {
      if (_rptTitleCtrl.text.trim().isEmpty) { _showError('Please enter a headline.'); return; }
      setState(() => _submitting = true);

      final headline = _rptTitleCtrl.text.trim();
      final crop = _rptCropCtrl.text.trim();
      final loc = _rptLocationCtrl.text.trim();
      final shortParts = [headline];
      if (crop.isNotEmpty) shortParts.add('[$crop]');
      if (loc.isNotEmpty) shortParts.add('— $loc');

      // Process images for all modes:
      // Online — upload to Firebase Storage and store the URL.
      // Offline — keep the local path; it will be uploaded when connectivity is restored.
      for (final mode in ['text', 'manual', 'visual']) {
        for (final block in _blocks[mode]!) {
          if (block['type'] == 'image' && block['file'] != null) {
            if (state.isOnline) {
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
            } else {
              // Offline: store local path in the controller for later upload
              (block['ctrl'] as TextEditingController).text =
                  (block['file'] as XFile).path;
            }
          }
        }
      }

      // Convert blocks from each mode to text and store in the appropriate fields
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

      final reportQueued = await state.addPost(Post(
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
        isVerified: userPrefs.isExpert,
        location: _resolvedLocation,
        viewMode: _activeMode,
        dictCrop: crop,
        dictTags: _tags,
        postType: 'report',
        avatarBase64: userPrefs.avatarBase64,
      ));
      if (reportQueued == null) {
        setState(() => _submitting = false);
        if (mounted) _showError('Offline queue is full (max ${OfflineQueueService.maxQueueSize}). Please retry when online.');
        return;
      }
    }

    setState(() => _submitting = false);
    if (!mounted) return;
    await PostDraftService.clearDraft();
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
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
                        onPressed: _handleBack,
                      ),
                      const Text('New post',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    Row(children: [
                    if (_postType == 'report')
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'excel',
                            child: Row(
                              children: [
                                Icon(Icons.table_view_outlined, size: 16, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Import Excel (.xlsx)'),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (v) {
                          if (v == 'excel') _importFromExcel();
                        },
                      ),
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
                    ]),
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
            child: Row(
              children: [
                if (_postType == 'report') ...[
                  OutlinedButton.icon(
                    onPressed: _showPreview,
                    icon: const Icon(Icons.preview_outlined, size: 16),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: SizedBox(
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
          ),
        ],
      ),
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
          maxLength: 500,
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
        RawAutocomplete<String>(
          textEditingController: _tagCtrl,
          focusNode: _tagFocusNode,
          optionsBuilder: (textEditingValue) {
            final input = textEditingValue.text.trim().toLowerCase();
            if (input.isEmpty) return const [];
            return _availableTags
                .where((tag) =>
                    tag.contains(input) &&
                    !_tags.contains(tag))
                .take(6);
          },
          onSelected: (tag) {
            if (!_tags.contains(tag)) {
              setState(() {
                _tags.add(tag);
                _tagCtrl.clear();
              });
            }
          },
          fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
            return Row(children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Add keyword + Enter  (e.g. maize, stem borer…)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
            ]);
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: options
                        .map((tag) => InkWell(
                              onTap: () => onSelected(tag),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  const Icon(Icons.label_outline,
                                      size: 14,
                                      color: AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(tag,
                                      style: const TextStyle(fontSize: 13)),
                                ]),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            );
          },
        ),
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
              Stack(
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
                  if (type == 'heading' || type == 'text')
                    Positioned(
                      bottom: 8,
                      right: 4,
                      child: Tooltip(
                        message: type == 'heading' ? 'Switch to text' : 'Switch to heading',
                        child: GestureDetector(
                          onTap: () => _toggleBlockType(id),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              type == 'heading' ? Icons.text_fields : Icons.title,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
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
          // Image blocks are not available in text-only mode
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
  final LatLng? currentGps; // position for the blue GPS dot
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
                    // Blue dot for the user's current GPS position
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
                // Center pin — the post will be attached to this location
                const IgnorePointer(
                  child: Icon(Icons.location_on, color: AppColors.primary, size: 40),
                ),
                // Coordinate display overlay
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

// Google Maps-style current location dot
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
