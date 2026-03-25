import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';

/// Kenya bounding box + tile download / cache management.
class MapTileService {
  static const _minLon = 33.9;
  static const _maxLon = 42.0;
  static const _minLat = -5.0;
  static const _maxLat = 5.0;

  static const _tileBase =
      'https://a.basemaps.cartocdn.com/rastertiles/voyager';
  static const _cacheFolder = 'map_tiles';

  // ─── Download presets ──────────────────────────────────────────────────────

  static const List<MapTilePreset> presets = [
    MapTilePreset(
      label: 'Overview',
      description: 'Country-level overview. Fast to download.',
      minZoom: 5,
      maxZoom: 8,
      estimatedMb: '~1 MB',
    ),
    MapTilePreset(
      label: 'Standard',
      description: 'County-level detail. Good for everyday use.',
      minZoom: 5,
      maxZoom: 10,
      estimatedMb: '~12 MB',
    ),
    MapTilePreset(
      label: 'Detailed',
      description: 'Ward-level detail. Matches the app\'s default zoom.',
      minZoom: 5,
      maxZoom: 12,
      estimatedMb: '~50 MB',
    ),
  ];

  // ─── Tile coordinate math ──────────────────────────────────────────────────

  static int _lon2x(double lon, int z) =>
      ((lon + 180) / 360 * math.pow(2, z)).floor();

  static int _lat2y(double lat, int z) {
    final r = lat * math.pi / 180;
    return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) /
            2 *
            math.pow(2, z))
        .floor();
  }

  static ({int xMin, int xMax, int yMin, int yMax}) _kenyaBounds(int z) => (
        xMin: _lon2x(_minLon, z),
        xMax: _lon2x(_maxLon, z),
        yMin: _lat2y(_maxLat, z), // y=0 is north
        yMax: _lat2y(_minLat, z),
      );

  static int tilesForZoom(int z) {
    final b = _kenyaBounds(z);
    return (b.xMax - b.xMin + 1) * (b.yMax - b.yMin + 1);
  }

  static int totalTiles(int minZ, int maxZ) {
    int total = 0;
    for (int z = minZ; z <= maxZ; z++) {
      total += tilesForZoom(z);
    }
    return total;
  }

  // ─── Cache directory ──────────────────────────────────────────────────────

  static Future<Directory> _getDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_cacheFolder');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<String> getDirPath() async => (await _getDir()).path;

  // ─── Cache status ─────────────────────────────────────────────────────────

  static Future<({int bytes, int maxZoom})> cacheStatus() async {
    try {
      final dir = await _getDir();
      if (!await dir.exists()) return (bytes: 0, maxZoom: 0);
      int total = 0;
      int maxZ = 0;
      await for (final e in dir.list(recursive: true)) {
        if (e is File) {
          total += await e.length();
        } else if (e is Directory) {
          final name = e.path.split('/').last;
          final z = int.tryParse(name) ?? 0;
          if (z > maxZ && z < 20) maxZ = z;
        }
      }
      return (bytes: total, maxZoom: maxZ);
    } catch (_) {
      return (bytes: 0, maxZoom: 0);
    }
  }

  static Future<bool> hasCachedTiles() async =>
      (await cacheStatus()).maxZoom > 0;

  static Future<void> clearCache() async {
    try {
      final dir = await _getDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  // ─── Download ─────────────────────────────────────────────────────────────

  static Future<void> downloadTiles(
    int minZ,
    int maxZ, {
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final dir = await _getDir();
    final total = totalTiles(minZ, maxZ);
    int done = 0;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 10);

    try {
      for (int z = minZ; z <= maxZ; z++) {
        if (isCancelled()) return;
        final b = _kenyaBounds(z);
        for (int x = b.xMin; x <= b.xMax; x++) {
          for (int y = b.yMin; y <= b.yMax; y++) {
            if (isCancelled()) return;

            final file = File('${dir.path}/$z/$x/$y.png');
            if (!await file.exists()) {
              try {
                final req =
                    await client.getUrl(Uri.parse('$_tileBase/$z/$x/$y.png'));
                req.headers.set('User-Agent', 'agridict/1.0');
                final res = await req.close();
                if (res.statusCode == 200) {
                  final bytes = await consolidateHttpClientResponseBytes(res);
                  await file.parent.create(recursive: true);
                  await file.writeAsBytes(bytes);
                }
              } catch (e) {
                debugPrint('[MapTile] $z/$x/$y failed: $e');
              }
            }

            done++;
            onProgress(done, total);
            // Small pause to respect server rate limits
            await Future.delayed(const Duration(milliseconds: 25));
          }
        }
      }
    } finally {
      client.close();
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String formatBytes(int bytes) {
    if (bytes == 0) return '0 B';
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Preset model ─────────────────────────────────────────────────────────────

class MapTilePreset {
  final String label;
  final String description;
  final int minZoom;
  final int maxZoom;
  final String estimatedMb;

  const MapTilePreset({
    required this.label,
    required this.description,
    required this.minZoom,
    required this.maxZoom,
    required this.estimatedMb,
  });
}

// ─── Custom TileProvider (local cache → network fallback) ────────────────────

class CachedMapTileProvider extends TileProvider {
  final String cacheDirPath;
  static const _base = 'https://a.basemaps.cartocdn.com/rastertiles/voyager';

  CachedMapTileProvider({required this.cacheDirPath});

  @override
  ImageProvider<Object> getImage(
      TileCoordinates coordinates, TileLayer options) {
    final path =
        '$cacheDirPath/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
    final file = File(path);
    if (file.existsSync()) return FileImage(file);
    return NetworkImage(
        '$_base/${coordinates.z}/${coordinates.x}/${coordinates.y}.png');
  }
}
