import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../storage/storage_providers.dart';
import '../domain/asset_record.dart';
import 'asset_thumbnail_cache.dart';

abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}

class LocalAssetPreviewProvider implements AssetPreviewProvider {
  const LocalAssetPreviewProvider(this._thumbnailCache);

  final AssetThumbnailCache _thumbnailCache;

  @override
  Future<Uint8List?> thumbnail(AssetRecord asset) async {
    for (final candidate in [asset.thumbnailPath, asset.previewPath]) {
      if (candidate == null || candidate.isEmpty) continue;
      final bytes = await _readBestEffort(File(candidate));
      if (bytes != null) return bytes;
    }

    return _thumbnailCache.thumbnail(asset);
  }

  static Future<Uint8List?> _readBestEffort(File file) async {
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}

final assetThumbnailCacheProvider = Provider<AssetThumbnailCache>((ref) {
  final storePath = ref.watch(assetsStoreProvider).path;
  final root = storePath == null
      ? Directory(p.join(Directory.systemTemp.path, 'dextryx_images_thumbnails'))
      : Directory(p.join(p.dirname(storePath), 'thumbnail_cache'));
  return AssetThumbnailCache(root: root);
});

final assetPreviewProvider = Provider<AssetPreviewProvider>((ref) {
  return LocalAssetPreviewProvider(ref.watch(assetThumbnailCacheProvider));
});
