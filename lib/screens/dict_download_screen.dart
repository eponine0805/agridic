import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_prefs.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class DictDownloadScreen extends StatefulWidget {
  /// isFirstRun = true means shown as mandatory onboarding step
  final bool isFirstRun;
  const DictDownloadScreen({super.key, this.isFirstRun = true});

  @override
  State<DictDownloadScreen> createState() => _DictDownloadScreenState();
}

class _DictDownloadScreenState extends State<DictDownloadScreen> {
  int _dictCount = 0;
  bool _loadingCount = true;
  bool _downloading = false;
  int _downloadedCount = 0;
  String? _downloadError;
  bool _done = false;

  // Per-entry estimated sizes in KB
  static const _textKb = 5;
  static const _thumbKb = 50;
  static const _fullKb = 500;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    try {
      final n = await FirebaseService.getDictionaryPostCount();
      if (mounted) setState(() {
        _dictCount = n;
        _loadingCount = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _dictCount = 0;
        _loadingCount = false;
      });
    }
  }

  String _formatKb(int kb) {
    if (kb < 1024) return '~${kb}KB';
    return '~${(kb / 1024).toStringAsFixed(1)}MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _downloadedCount = 0;
      _downloadError = null;
    });
    try {
      final posts = await FirebaseService.fetchDictionaryPosts();
      final prefs = await SharedPreferences.getInstance();
      final jsonList = <String>[];
      for (final post in posts) {
        // Store only JSON-safe fields (no Timestamp/FieldValue objects)
        final entry = {
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
          'imageLow': post.content.imageLow,
          'steps': post.content.steps,
        };
        jsonList.add(jsonEncode(entry));
        if (mounted) setState(() => _downloadedCount++);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await prefs.setStringList('dict_cache', jsonList);
      await context.read<UserPrefs>().markFirstDownloadDone();
      if (mounted) setState(() {
        _downloading = false;
        _done = true;
      });
    } catch (e) {
      if (mounted) setState(() {
        _downloading = false;
        _downloadError = e.toString();
      });
    }
  }

  Future<void> _skipDownload() async {
    await context.read<UserPrefs>().markFirstDownloadDone();
    if (mounted) Navigator.of(context).pop();
  }

  void _finish() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isFirstRun
          ? null
          : AppBar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              title: const Text('Dictionary download',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _done ? _buildDoneView() : _buildMainView(),
        ),
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isFirstRun) ...[
          const Icon(Icons.menu_book, color: AppColors.primary, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Download the Agricultural Guide',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save official farming guides to your device so you can access them offline, even without signal.',
            style: TextStyle(
                fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
        ],
        if (_loadingCount)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else ...[
          Text(
            _dictCount == 0
                ? 'No dictionary entries available yet.'
                : '$_dictCount guide${_dictCount == 1 ? '' : 's'} available',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          if (_dictCount > 0) ...[
            _ModeCard(
              icon: Icons.text_snippet_outlined,
              label: 'Text only',
              description:
                  'Guide text without images. Best for very weak signal.',
              size: _formatKb(_dictCount * _textKb),
              color: AppColors.primary,
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.auto_awesome_outlined,
              label: 'Text + thumbnails',
              description:
                  'Text with small images. Standard for everyday use.',
              size: _formatKb(_dictCount * _thumbKb),
              color: const Color(0xFF388E3C),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.image_outlined,
              label: 'Text + full images',
              description: 'Full-quality images. Recommended on Wi-Fi.',
              size: _formatKb(_dictCount * _fullKb),
              color: const Color(0xFF1565C0),
            ),
            const SizedBox(height: 8),
            const Text(
              'Size estimates are approximate. Your download includes all text and any available images.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
        const Spacer(),
        if (_downloading) ...[
          Text(
            'Downloading... $_downloadedCount / $_dictCount',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _dictCount > 0 ? _downloadedCount / _dictCount : null,
            backgroundColor: AppColors.modeActive,
            color: AppColors.primary,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 16),
        ] else if (_downloadError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Text(_downloadError!,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 12)),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: (_downloading || _loadingCount || _dictCount == 0)
                      ? null
                      : _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _downloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _downloadError != null ? 'Retry' : 'Download now',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _downloading ? null : _skipDownload,
              child: const Text('Skip for now',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDoneView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: AppColors.primary, size: 72),
        const SizedBox(height: 20),
        Text(
          'Downloaded $_downloadedCount guide${_downloadedCount == 1 ? '' : 's'}',
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'The agricultural guide is ready to use offline.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _finish,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Get started',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final String size;
  final Color color;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(size,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ),
        ],
      ),
    );
  }
}
