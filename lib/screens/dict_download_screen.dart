import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../services/dict_local_service.dart';
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
  ({int count, int textBytes, int thumbBytes, int fullBytes})? _info;
  bool _loadingInfo = true;
  bool _downloading = false;
  int _downloadedCount = 0;
  String? _downloadError;
  bool _done = false;

  /// 0 = text only, 1 = text + thumbnails, 2 = text + full images
  int _selectedMode = 1;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    try {
      final info = await FirebaseService.getDictionaryInfo();
      if (mounted) setState(() {
        _info = info;
        _loadingInfo = false;
      });
    } catch (e) {
      debugPrint('[DictDownloadScreen] getDictionaryInfo failed: $e');
      if (mounted) setState(() {
        _info = (count: 0, textBytes: 0, thumbBytes: 0, fullBytes: 0);
        _loadingInfo = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '~${(bytes / 1024).round()}KB';
    return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  int get _selectedBytes {
    final info = _info;
    if (info == null) return 0;
    return switch (_selectedMode) {
      0 => info.textBytes,
      1 => info.thumbBytes,
      _ => info.fullBytes,
    };
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _downloadedCount = 0;
      _downloadError = null;
    });
    try {
      final posts = await FirebaseService.fetchDictionaryPosts();
      for (var i = 0; i < posts.length; i++) {
        if (mounted) setState(() => _downloadedCount = i + 1);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      await DictLocalService.save(posts, _selectedMode);
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
    final info = _info;
    final count = info?.count ?? 0;

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
        if (_loadingInfo)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else ...[
          Text(
            count == 0
                ? 'No dictionary entries available yet.'
                : '$count guide${count == 1 ? '' : 's'} available',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose what to include in your download:',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (count > 0) ...[
            _ModeCard(
              icon: Icons.text_snippet_outlined,
              label: 'Text only',
              description:
                  'Guide text without images. Best for very weak signal.',
              size: _formatBytes(info!.textBytes),
              color: AppColors.primary,
              isSelected: _selectedMode == 0,
              onTap: () => setState(() => _selectedMode = 0),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.auto_awesome_outlined,
              label: 'Text + thumbnails',
              description:
                  'Text with small images. Standard for everyday use.',
              size: _formatBytes(info.thumbBytes),
              color: const Color(0xFF388E3C),
              isSelected: _selectedMode == 1,
              onTap: () => setState(() => _selectedMode = 1),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.image_outlined,
              label: 'Text + full images',
              description: 'Full-quality images. Recommended on Wi-Fi.',
              size: _formatBytes(info.fullBytes),
              color: const Color(0xFF1565C0),
              isSelected: _selectedMode == 2,
              onTap: () => setState(() => _selectedMode = 2),
            ),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_formatBytes(_selectedBytes)} — size includes text and any available images.',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
        const Spacer(),
        if (_downloading) ...[
          Text(
            'Downloading... $_downloadedCount / ${_info?.count ?? 0}',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: ((_info?.count ?? 0) > 0)
                ? _downloadedCount / _info!.count
                : null,
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
                  onPressed: (_downloading || _loadingInfo || count == 0)
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
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.size,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.10) : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: isSelected,
              onChanged: (_) => onTap(),
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 12),
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
      ),
    );
  }
}
