import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/asset_record.dart';

abstract interface class AssetPreviewProvider {
  Future<Uint8List?> thumbnail(AssetRecord asset);
}

class LocalAssetPreviewProvider implements AssetPreviewProvider {
  const LocalAssetPreviewProvider();

  @override
  Future<Uint8List?> thumbnail(AssetRecord asset) async {
    final candidate = asset.thumbnailPath ?? asset.previewPath;
    if (candidate == null || candidate.isEmpty) return null;
    final file = File(candidate);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }
}

final assetPreviewProvider = Provider<AssetPreviewProvider>((ref) {
  return const LocalAssetPreviewProvider();
});
