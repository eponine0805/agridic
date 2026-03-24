import 'package:flutter_test/flutter_test.dart';
import 'package:agridic/services/map_tile_service.dart';

void main() {
  group('MapTileService.formatBytes', () {
    test('zero bytes', () {
      expect(MapTileService.formatBytes(0), '0 B');
    });

    test('bytes (< 1 KB)', () {
      expect(MapTileService.formatBytes(512), '512 B');
    });

    test('kilobytes', () {
      expect(MapTileService.formatBytes(2048), '2 KB');
    });

    test('megabytes', () {
      expect(MapTileService.formatBytes(5 * 1024 * 1024), '5.0 MB');
    });

    test('fractional megabytes', () {
      expect(MapTileService.formatBytes((1.5 * 1024 * 1024).round()), '1.5 MB');
    });
  });

  group('MapTileService tile counts', () {
    test('tilesForZoom at zoom 5 returns positive count', () {
      final count = MapTileService.tilesForZoom(5);
      expect(count, greaterThan(0));
    });

    test('tilesForZoom increases with zoom level', () {
      final z5 = MapTileService.tilesForZoom(5);
      final z6 = MapTileService.tilesForZoom(6);
      final z7 = MapTileService.tilesForZoom(7);
      expect(z6, greaterThan(z5));
      expect(z7, greaterThan(z6));
    });

    test('totalTiles for single zoom equals tilesForZoom', () {
      expect(MapTileService.totalTiles(8, 8), MapTileService.tilesForZoom(8));
    });

    test('totalTiles sums correctly across zoom range', () {
      final total = MapTileService.totalTiles(5, 7);
      final expected = MapTileService.tilesForZoom(5) +
          MapTileService.tilesForZoom(6) +
          MapTileService.tilesForZoom(7);
      expect(total, expected);
    });

    test('Overview preset has positive tile count', () {
      final preset = MapTileService.presets[0];
      expect(
          MapTileService.totalTiles(preset.minZoom, preset.maxZoom),
          greaterThan(0));
    });
  });
}
