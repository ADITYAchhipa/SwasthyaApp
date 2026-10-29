import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Manages local persistent disk storage for map tiles so maps render offline.
class OfflineMapCacheManager {
  static Directory? _cacheDir;

  static Future<Directory> getCacheDirectory() async {
    if (_cacheDir != null) return _cacheDir!;
    final basePath = await getDatabasesPath();
    final dir = Directory(p.join(basePath, 'map_tile_cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  static String getTileFileName(int z, int x, int y) => '${z}_${x}_${y}.png';

  static Future<File> getTileFile(int z, int x, int y) async {
    final dir = await getCacheDirectory();
    return File(p.join(dir.path, getTileFileName(z, x, y)));
  }

  static Future<bool> isTileCached(int z, int x, int y) async {
    final file = await getTileFile(z, x, y);
    return file.exists();
  }

  static Future<int> getCachedTilesCount() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) return 0;
      return dir.listSync().whereType<File>().length;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> getCacheSizeBytes() async {
    try {
      final dir = await getCacheDirectory();
      if (!await dir.exists()) return 0;
      int total = 0;
      for (final entity in dir.listSync()) {
        if (entity is File) {
          total += entity.lengthSync();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clearCache() async {
    try {
      final dir = await getCacheDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cacheDir = null;
      }
    } catch (_) {}
  }

  /// Converts GPS longitude to tile X coordinate at given zoom.
  static int lon2tile(double lon, int zoom) =>
      ((lon + 180.0) / 360.0 * (1 << zoom)).floor();

  /// Converts GPS latitude to tile Y coordinate at given zoom.
  static int lat2tile(double lat, int zoom) {
    final rad = lat * pi / 180.0;
    final n = (1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0;
    return (n * (1 << zoom)).floor();
  }

  /// Pre-downloads map tiles for an area around [center] for specified zooms.
  /// [radiusKm] defines the bounding box around the center coordinate.
  static Future<int> precacheArea(
    LatLng center, {
    int minZoom = 13,
    int maxZoom = 15,
    double radiusKm = 4.0,
    void Function(int current, int total)? onProgress,
  }) async {
    final client = http.Client();
    int downloaded = 0;

    try {
      // 1 deg latitude is approximately 111 km
      final latDelta = radiusKm / 111.0;
      final lngDelta = radiusKm / (111.0 * cos(center.latitude * pi / 180.0));

      final minLat = center.latitude - latDelta;
      final maxLat = center.latitude + latDelta;
      final minLng = center.longitude - lngDelta;
      final maxLng = center.longitude + lngDelta;

      final tilesToFetch = <List<int>>[];

      for (int z = minZoom; z <= maxZoom; z++) {
        final x1 = lon2tile(minLng, z);
        final x2 = lon2tile(maxLng, z);
        final y1 = lat2tile(maxLat, z); // Note: tile Y is inverted (top is 0)
        final y2 = lat2tile(minLat, z);

        final minX = min(x1, x2);
        final maxX = max(x1, x2);
        final minY = min(y1, y2);
        final maxY = max(y1, y2);

        for (int x = minX; x <= maxX; x++) {
          for (int y = minY; y <= maxY; y++) {
            tilesToFetch.add([z, x, y]);
          }
        }
      }

      final total = tilesToFetch.length;
      onProgress?.call(0, total);

      // Fetch with concurrency limit of 4
      const concurrency = 4;
      for (int i = 0; i < tilesToFetch.length; i += concurrency) {
        final chunk = tilesToFetch.sublist(i, min(i + concurrency, tilesToFetch.length));
        await Future.wait(chunk.map((coord) async {
          final z = coord[0];
          final x = coord[1];
          final y = coord[2];

          final file = await getTileFile(z, x, y);
          if (await file.exists()) {
            downloaded++;
            return;
          }

          final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';
          try {
            final res = await client.get(
              Uri.parse(url),
              headers: {'User-Agent': 'SwasthyaTap/1.0 (offline-map-cache)'},
            ).timeout(const Duration(seconds: 5));

            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              await file.writeAsBytes(res.bodyBytes);
              downloaded++;
            }
          } catch (_) {}
        }));
        onProgress?.call(downloaded, total);
      }
    } finally {
      client.close();
    }

    return downloaded;
  }
}

/// A [TileProvider] that saves downloaded tiles to local disk and serves them offline.
class OfflineMapTileProvider extends TileProvider {
  OfflineMapTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    var url = options.urlTemplate ?? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    url = url.replaceAll('{z}', coordinates.z.toString());
    url = url.replaceAll('{x}', coordinates.x.toString());
    url = url.replaceAll('{y}', coordinates.y.toString());

    return OfflineCachedTileImageProvider(
      url: url,
      coordinates: coordinates,
      headers: headers,
    );
  }
}

/// Custom [ImageProvider] that transparently loads from disk cache first,
/// fetches from network if online, and falls back gracefully when offline.
class OfflineCachedTileImageProvider extends ImageProvider<OfflineCachedTileImageProvider> {
  final String url;
  final TileCoordinates coordinates;
  final Map<String, String>? headers;

  const OfflineCachedTileImageProvider({
    required this.url,
    required this.coordinates,
    this.headers,
  });

  @override
  Future<OfflineCachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineCachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    OfflineCachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'OfflineCachedTile(${coordinates.z}/${coordinates.x}/${coordinates.y})',
    );
  }

  Future<ui.Codec> _loadAsync(
    OfflineCachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final file = await OfflineMapCacheManager.getTileFile(
        coordinates.z,
        coordinates.x,
        coordinates.y,
      );

      // 1. If tile file already exists in local disk cache, serve it immediately!
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return await decode(buffer);
        }
      }

      // 2. Not cached: fetch from network and save to disk
      final reqHeaders = <String, String>{
        'User-Agent': 'SwasthyaTap/1.0 (offline-map-cache)',
        if (headers != null) ...headers!,
      };

      final response = await http.get(Uri.parse(url), headers: reqHeaders).timeout(
        const Duration(seconds: 4),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        unawaited(file.writeAsBytes(response.bodyBytes));
        final buffer = await ui.ImmutableBuffer.fromUint8List(response.bodyBytes);
        return await decode(buffer);
      }
    } catch (_) {
      // Offline / network failure
    }

    // 3. Fallback when offline and tile was not previously cached:
    // Return a 1x1 transparent PNG pixel so flutter_map renders smoothly without error.
    final fallbackBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(fallbackBytes);
    return await decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is OfflineCachedTileImageProvider &&
        other.coordinates.x == coordinates.x &&
        other.coordinates.y == coordinates.y &&
        other.coordinates.z == coordinates.z &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(coordinates.x, coordinates.y, coordinates.z, url);
}
