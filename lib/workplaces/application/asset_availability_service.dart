import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/asset_record.dart';

abstract interface class AssetFileSystem {
  Future<bool> exists(String path);
  Future<List<String>> filesUnder(String root);
}

class LocalAssetFileSystem implements AssetFileSystem {
  const LocalAssetFileSystem();

  @override
  Future<bool> exists(String path) => File(path).exists();

  @override
  Future<List<String>> filesUnder(String root) async {
    final directory = Directory(root);
    if (!await directory.exists()) return const [];
    final files = <String>[];
    await for (final entity in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) files.add(p.normalize(entity.absolute.path));
    }
    return files;
  }
}

final assetFileSystemProvider = Provider<AssetFileSystem>((ref) {
  return const LocalAssetFileSystem();
});

class AssetAvailabilityService {
  AssetAvailabilityService(this._fileSystem);

  final AssetFileSystem _fileSystem;

  Future<Map<String, bool>> missingById(
    Iterable<AssetRecord> assets, {
    int batchSize = 32,
  }) async {
    final items = assets.toList(growable: false);
    final result = <String, bool>{};
    for (var offset = 0; offset < items.length; offset += batchSize) {
      final end = math.min(offset + batchSize, items.length);
      final batch = items.sublist(offset, end);
      final existence = await Future.wait(
        batch.map((asset) => _fileSystem.exists(asset.effectivePath)),
      );
      for (var index = 0; index < batch.length; index++) {
        result[batch[index].id] = !existence[index];
      }
      await Future<void>.delayed(Duration.zero);
    }
    return result;
  }

  Future<Map<String, String>> filesByLowercaseFilename(String root) async {
    final result = <String, String>{};
    for (final path in await _fileSystem.filesUnder(root)) {
      result.putIfAbsent(p.basename(path).toLowerCase(), () => path);
    }
    return result;
  }
}

final assetAvailabilityServiceProvider = Provider<AssetAvailabilityService>((ref) {
  return AssetAvailabilityService(ref.watch(assetFileSystemProvider));
});
