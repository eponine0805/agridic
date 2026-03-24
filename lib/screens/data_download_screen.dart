import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_prefs.dart';
import '../services/dict_local_service.dart';
import '../services/firebase_service.dart';
import '../services/map_tile_service.dart';
import '../utils/app_colors.dart';

/// Unified offline data download screen.
/// Tab 0 — Dictionary  (text/thumbnail/full-image presets)
/// Tab 1 — Map         (Kenya tile cache at various zoom depths)
class DataDownloadScreen extends StatefulWidget {
  /// When true, shown as mandatory onboarding step (no back button, no skip).
  final bool isFirstRun;

  const DataDownloadScreen({super.key, this.isFirstRun = false});

  @override
  State<DataDownloadScreen> createState() => _DataDownloadScreenState();
}

class _DataDownloadScreenState extends State<DataDownloadScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.isFirstRun,
        title: Text(
          widget.isFirstRun ? 'Setup Offline Data' : 'Data Downloads',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Dictionary'),
            Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Map'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _DictTab(isFirstRun: widget.isFirstRun),
          const _MapTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DICTIONARY TAB
// ══════════════════════════════════════════════════════════════════════════════

class _DictTab extends StatefulWidget {
  final bool isFirstRun;
  const _DictTab({required this.isFirstRun});

  @override
  State<_DictTab> createState() => _DictTabState();
}

class _DictTabState extends State<_DictTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ({int count, int textBytes, int thumbBytes, int fullBytes})? _info;
  bool _loadingInfo = true;
  bool _downloading = false;
  int _downloadedCount = 0;
  String? _error;
  bool _done = false;

  DateTime? _cachedSavedAt;
  int _cachedCount = 0;
  Set<String> _cachedIds = {};
  int _selectedMode = 1; // 0=text, 1=thumbs, 2=full

  bool get _isIncremental => !widget.isFirstRun && _cachedSavedAt != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadingInfo = true);
    try {
      if (!widget.isFirstRun) {
        final cached = await DictLocalService.load();
        _cachedSavedAt = cached.savedAt;
        _cachedCount = cached.posts.length;
        _selectedMode = cached.mode;
        _cachedIds = cached.posts.map((p) => p.postId).toSet();
      }
      final info = await FirebaseService.getDictionaryInfo(
        excludeIds: _isIncremental ? _cachedIds : null,
      );
      if (mounted) setState(() { _info = info; _loadingInfo = false; });
    } catch (_) {
      if (mounted) setState(() {
        _info = (count: 0, textBytes: 0, thumbBytes: 0, fullBytes: 0);
        _loadingInfo = false;
      });
    }
  }

  String _fmt(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '~${(bytes / 1024).round()} KB';
    return '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int get _selectedBytes {
    final i = _info;
    if (i == null) return 0;
    return switch (_selectedMode) {
      0 => i.textBytes,
      1 => i.thumbBytes,
      _ => i.fullBytes,
    };
  }

  Future<void> _startDownload() async {
    setState(() { _downloading = true; _downloadedCount = 0; _error = null; });
    try {
      final posts = await FirebaseService.fetchDictionaryPosts();
      for (var i = 0; i < posts.length; i++) {
        if (mounted) setState(() => _downloadedCount = i + 1);
        await Future.delayed(const Duration(milliseconds: 10));
      }
      int total;
      if (_isIncremental) {
        total = await DictLocalService.merge(posts, _selectedMode);
      } else {
        await DictLocalService.save(posts, _selectedMode);
        total = posts.length;
      }
      await context.read<UserPrefs>().markFirstDownloadDone();
      if (mounted) setState(() {
        _downloadedCount = total;
        _downloading = false;
        _done = true;
      });
    } catch (e) {
      if (mounted) setState(() { _downloading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_done) return _buildDone();
    return _buildMain();
  }

  Widget _buildMain() {
    final info = _info;
    final count = info?.count ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agricultural Guide',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('Official farming guides — available offline',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),

          if (_loadingInfo)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else ...[
            // Existing cache banner
            if (_isIncremental)
              _InfoBanner(
                icon: Icons.inventory_2_outlined,
                text: 'Already saved: $_cachedCount guides  •  '
                    'Saved ${_agoCached(_cachedSavedAt!)}',
              ),
            if (_isIncremental) const SizedBox(height: 10),

            // Available count
            Text(
              count == 0
                  ? (_isIncremental ? 'Everything is up to date.' : 'No guides available yet.')
                  : (_isIncremental
                      ? '$count new guide${count == 1 ? '' : 's'} available'
                      : '$count guide${count == 1 ? '' : 's'} available to download'),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _isIncremental
                  ? 'Only new guides will be added to your device.'
                  : 'Choose what to include in your offline library:',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),

            if (count > 0) ...[
              _ModeCard(
                icon: Icons.text_snippet_outlined,
                label: 'Text only',
                description: 'Guide text without images. Best for weak signal.',
                size: _fmt(info!.textBytes),
                color: AppColors.primary,
                isSelected: _selectedMode == 0,
                onTap: () => setState(() => _selectedMode = 0),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                icon: Icons.auto_awesome_outlined,
                label: 'Text + thumbnails',
                description: 'Text with small preview images. Standard choice.',
                size: _fmt(info.thumbBytes),
                color: const Color(0xFF388E3C),
                isSelected: _selectedMode == 1,
                onTap: () => setState(() => _selectedMode = 1),
              ),
              const SizedBox(height: 10),
              _ModeCard(
                icon: Icons.image_outlined,
                label: 'Text + full images',
                description: 'Full-quality images. Best downloaded on Wi-Fi.',
                size: _fmt(info.fullBytes),
                color: const Color(0xFF1565C0),
                isSelected: _selectedMode == 2,
                onTap: () => setState(() => _selectedMode = 2),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.download_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Selected size: ${_fmt(_selectedBytes)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ]),
            ],
            const SizedBox(height: 20),

            // Progress
            if (_downloading) ...[
              Text(
                'Downloading… $_downloadedCount / ${_info?.count ?? 0}',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((_info?.count ?? 0) > 0)
                      ? _downloadedCount / _info!.count
                      : null,
                  backgroundColor: AppColors.modeActive,
                  color: AppColors.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_error != null) ...[
              _ErrorBanner(message: _error!),
              const SizedBox(height: 12),
            ],

            // Buttons
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
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              _error != null
                                  ? 'Retry'
                                  : (_isIncremental && count == 0)
                                      ? 'Already up to date'
                                      : (_isIncremental
                                          ? 'Download $count new guide${count == 1 ? '' : 's'}'
                                          : 'Download  •  ${_fmt(_selectedBytes)}'),
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                if (widget.isFirstRun) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _downloading
                        ? null
                        : () async {
                            await context
                                .read<UserPrefs>()
                                .markFirstDownloadDone();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                    child: const Text('Skip',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDone() {
    final added = _isIncremental
        ? (_downloadedCount - _cachedCount).clamp(0, _downloadedCount)
        : _downloadedCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: AppColors.primary, size: 72),
            const SizedBox(height: 16),
            Text(
              _isIncremental
                  ? (added == 0
                      ? 'Already up to date'
                      : '+$added new guide${added == 1 ? '' : 's'} added')
                  : 'Downloaded $_downloadedCount guide${_downloadedCount == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Total: $_downloadedCount guides saved on device.',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (widget.isFirstRun) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() { _done = false; _load(); });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                    widget.isFirstRun ? 'Get started' : 'Done',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _agoCached(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MAP TAB
// ══════════════════════════════════════════════════════════════════════════════

class _MapTab extends StatefulWidget {
  const _MapTab();

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  ({int bytes, int maxZoom})? _cacheInfo;
  bool _loadingStatus = true;
  bool _downloading = false;
  bool _cancelled = false;
  int _dlDone = 0;
  int _dlTotal = 0;
  String? _error;

  int _selectedPreset = 1; // default: Standard

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    final info = await MapTileService.cacheStatus();
    if (mounted) setState(() { _cacheInfo = info; _loadingStatus = false; });
  }

  Future<void> _startDownload() async {
    final preset = MapTileService.presets[_selectedPreset];
    setState(() {
      _downloading = true;
      _cancelled = false;
      _dlDone = 0;
      _dlTotal = MapTileService.totalTiles(preset.minZoom, preset.maxZoom);
      _error = null;
    });
    try {
      await MapTileService.downloadTiles(
        preset.minZoom,
        preset.maxZoom,
        onProgress: (done, total) {
          if (mounted) setState(() { _dlDone = done; _dlTotal = total; });
        },
        isCancelled: () => _cancelled,
      );
      if (!_cancelled) await _loadStatus();
      if (mounted) setState(() => _downloading = false);
    } catch (e) {
      if (mounted) setState(() { _downloading = false; _error = e.toString(); });
    }
  }

  void _cancel() {
    setState(() { _cancelled = true; _downloading = false; });
  }

  Future<void> _clearCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear map cache?'),
        content: const Text(
            'Downloaded map tiles will be deleted. The map will load from the network when online.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await MapTileService.clearCache();
      await _loadStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.map_outlined, color: AppColors.accent, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kenya Map Tiles',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('Browse the map without internet',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Cache status
          if (_loadingStatus)
            const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
          else ...[
            _buildCacheStatus(),
            const SizedBox(height: 20),

            const Text('Download level',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),

            ...MapTileService.presets.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ModeCard(
                  icon: i == 0
                      ? Icons.zoom_out_map
                      : i == 1
                          ? Icons.map_outlined
                          : Icons.satellite_alt_outlined,
                  label: p.label,
                  description: '${p.description}  •  zoom ${p.minZoom}–${p.maxZoom}  '
                      '(${MapTileService.totalTiles(p.minZoom, p.maxZoom)} tiles)',
                  size: p.estimatedMb,
                  color: i == 0
                      ? AppColors.primary
                      : i == 1
                          ? const Color(0xFF388E3C)
                          : const Color(0xFF1565C0),
                  isSelected: _selectedPreset == i,
                  onTap: () => setState(() => _selectedPreset = i),
                ),
              );
            }),

            const SizedBox(height: 4),

            // Progress
            if (_downloading) ...[
              const SizedBox(height: 8),
              Text(
                'Downloading tiles… $_dlDone / $_dlTotal',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _dlTotal > 0 ? _dlDone / _dlTotal : null,
                  backgroundColor: AppColors.modeActive,
                  color: AppColors.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _cancel,
                  icon: const Icon(Icons.cancel_outlined,
                      size: 16, color: AppColors.danger),
                  label: const Text('Cancel',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ),
            ] else ...[
              if (_error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _startDownload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    (_cacheInfo?.maxZoom ?? 0) > 0
                        ? 'Re-download  •  ${MapTileService.presets[_selectedPreset].estimatedMb}'
                        : 'Download  •  ${MapTileService.presets[_selectedPreset].estimatedMb}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              if ((_cacheInfo?.bytes ?? 0) > 0) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: _clearCache,
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppColors.danger),
                    label: const Text('Clear tile cache',
                        style: TextStyle(color: AppColors.danger, fontSize: 13)),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCacheStatus() {
    final info = _cacheInfo;
    if (info == null || info.maxZoom == 0) {
      return _InfoBanner(
        icon: Icons.cloud_download_outlined,
        text: 'No map tiles cached yet — download below to use offline.',
        color: AppColors.textSecondary,
      );
    }
    return _InfoBanner(
      icon: Icons.offline_pin,
      text: 'Cached: ${MapTileService.formatBytes(info.bytes)}  •  '
          'zoom up to ${info.maxZoom}',
      color: AppColors.primary,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Text(message,
          style:
              const TextStyle(color: AppColors.danger, fontSize: 12)),
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
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.10)
              : color.withOpacity(0.04),
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
            Icon(icon, color: color, size: 24),
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
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
