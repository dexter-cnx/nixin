import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../domain/asset_record.dart';

typedef ThumbnailEncoder = Future<Uint8List?> Function(
  Uint8List sourceBytes,
  int maxDimension,
);
typedef ThumbnailValidator = Future<bool> Function(Uint8List bytes);

class AssetThumbnailCache {
  AssetThumbnailCache({
    required Directory root,
    this.maxDimension = 512,
    this.maxEntries = 2048,
    this.maxBytes = 512 * 1024 * 1024,
    this.maxConcurrentGenerations = 2,
    ThumbnailEncoder? encoder,
    ThumbnailValidator? validator,
  })  : assert(maxConcurrentGenerations > 0),
        _root = root,
        _encoder = encoder ?? _defaultEncoder,
        _validator = validator ?? _defaultValidator,
        _generationLimiter = _AsyncLimiter(maxConcurrentGenerations);

  final Directory _root;
  final int maxDimension;
  final int maxEntries;
  final int maxBytes;
  final int maxConcurrentGenerations;
  final ThumbnailEncoder _encoder;
  final ThumbnailValidator _validator;
  final _AsyncLimiter _generationLimiter;
  final Map<String, Future<Uint8List?>> _inFlight = {};

  Future<Uint8List?> thumbnail(AssetRecord asset) async {
    if (asset.mediaType != AssetMediaType.raster || asset.missing) return null;

    final source = File(asset.effectivePath);
    FileStat sourceStat;
    try {
      sourceStat = await source.stat();
      if (sourceStat.type != FileSystemEntityType.file) return null;
    } catch (_) {
      return null;
    }

    final cacheFile = File(p.join(_root.path, _cacheName(asset, sourceStat)));
    final cached = await _readValidCache(cacheFile);
    if (cached != null) return cached;

    return _inFlight.putIfAbsent(cacheFile.path, () async {
      try {
        return await _generationLimiter.run(
          () => _generate(asset, source, sourceStat, cacheFile),
        );
      } finally {
        _inFlight.remove(cacheFile.path);
      }
    });
  }

  Future<void> invalidate(AssetRecord asset) async {
    if (!await _root.exists()) return;
    final prefix = '${_safeId(asset.id)}-';
    try {
      await for (final entity in _root.list(followLinks: false)) {
        if (entity is File && p.basename(entity.path).startsWith(prefix)) {
          await _deleteBestEffort(entity);
        }
      }
    } on FileSystemException {
      // Cache may disappear during shutdown or external cleanup.
    }
  }

  Future<void> prune() async {
    if (!await _root.exists()) return;
    final files = <({File file, int bytes, DateTime modified})>[];
    var totalBytes = 0;
    try {
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
    } on FileSystemException {
      return;
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

  Future<Uint8List?> _generate(
    AssetRecord asset,
    File source,
    FileStat expectedStat,
    File cacheFile,
  ) async {
    FileStat currentStat;
    try {
      currentStat = await source.stat();
    } catch (_) {
      return null;
    }
    if (!_sameSourceVersion(expectedStat, currentStat)) return null;

    Uint8List sourceBytes;
    try {
      sourceBytes = await source.readAsBytes();
    } catch (_) {
      return null;
    }
    if (sourceBytes.isEmpty) return null;

    try {
      currentStat = await source.stat();
    } catch (_) {
      return null;
    }
    if (!_sameSourceVersion(expectedStat, currentStat)) return null;

    final encoded = await _encoder(sourceBytes, maxDimension);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      await _root.create(recursive: true);
      await _removeStaleVersions(asset, keepPath: cacheFile.path);
      final partial = File('${cacheFile.path}.partial');
      await _deleteBestEffort(partial);
      await partial.writeAsBytes(encoded, flush: true);
      await partial.rename(cacheFile.path);
      await prune();
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
      if (bytes.isNotEmpty && await _validator(bytes)) return bytes;
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
    try {
      await for (final entity in _root.list(followLinks: false)) {
        if (entity is File &&
            entity.path != keepPath &&
            p.basename(entity.path).startsWith(prefix)) {
          await _deleteBestEffort(entity);
        }
      }
    } on FileSystemException {
      // Cache cleanup races are intentionally non-fatal.
    }
  }

  static Future<void> _deleteBestEffort(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // A disposable cache entry must never make the catalog unavailable.
    }
  }

  static String _cacheName(AssetRecord asset, FileStat stat) =>
      '${_safeId(asset.id)}-${asset.modifiedAt.microsecondsSinceEpoch}-'
      '${stat.modified.microsecondsSinceEpoch}-${stat.size}.jpg';

  static bool _sameSourceVersion(FileStat a, FileStat b) =>
      a.type == b.type && a.size == b.size && a.modified == b.modified;

  static String _safeId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  static Future<Uint8List?> _defaultEncoder(
    Uint8List sourceBytes,
    int maxDimension,
  ) =>
      compute(_encodeThumbnail, <String, Object>{
        'bytes': sourceBytes,
        'maxDimension': maxDimension,
      });

  static Future<bool> _defaultValidator(Uint8List bytes) =>
      compute(_validateCachedJpeg, bytes);
}

class _AsyncLimiter {
  _AsyncLimiter(this.maxConcurrent);

  final int maxConcurrent;
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> run<T>(Future<T> Function() action) async {
    if (_active >= maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;
    try {
      return await action();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }
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

bool _validateCachedJpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return false;
  try {
    return img.decodeJpg(bytes) != null;
  } catch (_) {
    return false;
  }
}
