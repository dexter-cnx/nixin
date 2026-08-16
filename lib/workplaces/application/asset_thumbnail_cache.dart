import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../domain/asset_record.dart';

typedef ThumbnailEncoder = Future<Uint8List?> Function(
  Uint8List sourceBytes,
  int maxDimension,
);

class AssetThumbnailCache {
  AssetThumbnailCache({
    required Directory root,
    this.maxDimension = 512,
    this.maxEntries = 2048,
    this.maxBytes = 512 * 1024 * 1024,
    ThumbnailEncoder? encoder,
  })  : _root = root,
        _encoder = encoder ?? _defaultEncoder;

  final Directory _root;
  final int maxDimension;
  final int maxEntries;
  final int maxBytes;
  final ThumbnailEncoder _encoder;
  final Map<String, Future<Uint8List?>> _inFlight = {};

  Future<Uint8List?> thumbnail(AssetRecord asset) async {
    if (asset.mediaType != AssetMediaType.raster || asset.missing) return null;

    final cacheFile = File(p.join(_root.path, _cacheName(asset)));
    final cached = await _readValidCache(cacheFile);
    if (cached != null) return cached;

    return _inFlight.putIfAbsent(cacheFile.path, () async {
      try {
        return await _generate(asset, cacheFile);
      } finally {
        _inFlight.remove(cacheFile.path);
      }
    });
  }

  Future<void> invalidate(AssetRecord asset) async {
    if (!await _root.exists()) return;
    final prefix = '${_safeId(asset.id)}-';
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is File && p.basename(entity.path).startsWith(prefix)) {
        await _deleteBestEffort(entity);
      }
    }
  }

  Future<void> prune() async {
    if (!await _root.exists()) return;
    final files = <({File file, int bytes, DateTime modified})>[];
    var totalBytes = 0;
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is! File || entity.path.endsWith('.partial')) continue;
      try {
        final stat = await entity.stat();
        files.add((file: entity, bytes: stat.size, modified: stat.modified));
        totalBytes += stat.size;
      } catch (_) {
        // Cache maintenance is best-effort and must not affect catalog use.
      }
    }

    if (files.length <= maxEntries && totalBytes <= maxBytes) return;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    var count = files.length;
    for (final entry in files) {
      if (count <= maxEntries && totalBytes <= maxBytes) break;
      await _deleteBestEffort(entry.file);
      count--;
      totalBytes -= entry.bytes;
    }
  }

  Future<Uint8List?> _generate(AssetRecord asset, File cacheFile) async {
    final source = File(asset.effectivePath);
    if (!await source.exists()) return null;

    Uint8List sourceBytes;
    try {
      sourceBytes = await source.readAsBytes();
    } catch (_) {
      return null;
    }
    if (sourceBytes.isEmpty) return null;

    final encoded = await _encoder(sourceBytes, maxDimension);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      await _root.create(recursive: true);
      await _removeStaleVersions(asset, keepPath: cacheFile.path);
      final partial = File('${cacheFile.path}.partial');
      await _deleteBestEffort(partial);
      await partial.writeAsBytes(encoded, flush: true);
      await partial.rename(cacheFile.path);
      unawaited(prune());
      return encoded;
    } catch (_) {
      await _deleteBestEffort(File('${cacheFile.path}.partial'));
      return encoded;
    }
  }

  Future<Uint8List?> _readValidCache(File file) async {
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (_looksLikeJpeg(bytes)) return bytes;
    } catch (_) {
      return null;
    }
    await _deleteBestEffort(file);
    return null;
  }

  Future<void> _removeStaleVersions(
    AssetRecord asset, {
    required String keepPath,
  }) async {
    if (!await _root.exists()) return;
    final prefix = '${_safeId(asset.id)}-';
    await for (final entity in _root.list(followLinks: false)) {
      if (entity is File &&
          entity.path != keepPath &&
          p.basename(entity.path).startsWith(prefix)) {
        await _deleteBestEffort(entity);
      }
    }
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A disposable cache entry must never make the catalog unavailable.
    }
  }

  static String _cacheName(AssetRecord asset) =>
      '${_safeId(asset.id)}-${asset.modifiedAt.microsecondsSinceEpoch}.jpg';

  static String _safeId(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static bool _looksLikeJpeg(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[bytes.length - 2] == 0xff &&
      bytes[bytes.length - 1] == 0xd9;

  static Future<Uint8List?> _defaultEncoder(
    Uint8List sourceBytes,
    int maxDimension,
  ) =>
      compute(_encodeThumbnail, <String, Object>{
        'bytes': sourceBytes,
        'maxDimension': maxDimension,
      });
}

Uint8List? _encodeThumbnail(Map<String, Object> job) {
  final sourceBytes = job['bytes']! as Uint8List;
  final maxDimension = job['maxDimension']! as int;
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) return null;

  final largest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = largest <= maxDimension
      ? decoded
      : decoded.width >= decoded.height
          ? img.copyResize(
              decoded,
              width: maxDimension,
              interpolation: img.Interpolation.average,
            )
          : img.copyResize(
              decoded,
              height: maxDimension,
              interpolation: img.Interpolation.average,
            );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
}
