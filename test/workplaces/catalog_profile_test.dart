import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/asset_availability_service.dart';
import 'package:nixin_studio_v8/workplaces/application/asset_browser_controller.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/asset_repository.dart';

void main() {
  test('profiles 5000-asset load and sort without repository write amplification', () async {
    final assets = List.generate(5000, _asset);
    final repository = _ProfileAssetRepository(assets);
    final fileSystem = _ProfileFileSystem();
    final controller = AssetBrowserController(
      assetRepository: repository,
      availabilityService: AssetAvailabilityService(fileSystem),
      autoScanAvailability: false,
    );

    final loadWatch = Stopwatch()..start();
    await controller.load('workplace-1');
    loadWatch.stop();

    final sortWatch = Stopwatch()..start();
    controller.setSortOrder(AssetSortOrder.nameAscending);
    sortWatch.stop();

    expect(controller.state.assets, hasLength(5000));
    expect(repository.saveCount, 0);
    expect(controller.state.assets.first.originalFilename, 'image-00000.jpg');
    printOnFailure(
      'CATALOG_PROFILE load5000=${loadWatch.elapsedMicroseconds}us '
      'sort5000=${sortWatch.elapsedMicroseconds}us saves=${repository.saveCount}',
    );
  });

  test('profiles 5000-asset availability scan with bounded concurrency', () async {
    final assets = List.generate(5000, _asset);
    final repository = _ProfileAssetRepository(assets);
    final fileSystem = _ProfileFileSystem(delay: const Duration(milliseconds: 1));
    final controller = AssetBrowserController(
      assetRepository: repository,
      availabilityService: AssetAvailabilityService(fileSystem),
      autoScanAvailability: false,
    );
    await controller.load('workplace-1');

    final scanWatch = Stopwatch()..start();
    await controller.scanAvailability();
    scanWatch.stop();

    expect(fileSystem.calls, 5000);
    expect(fileSystem.maxConcurrent, lessThanOrEqualTo(32));
    expect(repository.saveCount, 0);
    expect(controller.state.missingCount, 0);
    printOnFailure(
      'CATALOG_PROFILE scan5000=${scanWatch.elapsedMilliseconds}ms '
      'maxConcurrent=${fileSystem.maxConcurrent} saves=${repository.saveCount}',
    );
  });

  test('availability scan persists only changed missing records', () async {
    final assets = List.generate(1000, _asset);
    final missingPaths = assets
        .take(25)
        .map((asset) => asset.effectivePath)
        .toSet();
    final repository = _ProfileAssetRepository(assets);
    final fileSystem = _ProfileFileSystem(missingPaths: missingPaths);
    final controller = AssetBrowserController(
      assetRepository: repository,
      availabilityService: AssetAvailabilityService(fileSystem),
      autoScanAvailability: false,
    );
    await controller.load('workplace-1');

    await controller.scanAvailability();

    expect(controller.state.missingCount, 25);
    expect(repository.saveCount, 25);
  });
}

AssetRecord _asset(int index) {
  final padded = index.toString().padLeft(5, '0');
  return AssetRecord(
    id: 'asset-$padded',
    workplaceId: 'workplace-1',
    originalFilename: 'image-$padded.jpg',
    sourcePath: '/catalog/image-$padded.jpg',
    storageMode: AssetStorageMode.linked,
    mediaType: AssetMediaType.raster,
    format: 'jpg',
    fileSize: 1024,
    importedAt: DateTime.utc(2026, 1, 1).add(Duration(seconds: index)),
    modifiedAt: DateTime.utc(2026, 1, 1),
  );
}

class _ProfileAssetRepository implements AssetRepository {
  _ProfileAssetRepository(List<AssetRecord> assets)
      : _assets = {for (final asset in assets) asset.id: asset};

  final Map<String, AssetRecord> _assets;
  int saveCount = 0;

  @override
  Future<void> delete(String id) async => _assets.remove(id);

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    _assets.removeWhere((_, asset) => asset.workplaceId == workplaceId);
  }

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async =>
      _assets.values.where((asset) => asset.workplaceId == workplaceId).toList();

  @override
  Future<AssetRecord?> getById(String id) async => _assets[id];

  @override
  Future<void> save(AssetRecord asset) async {
    saveCount++;
    _assets[asset.id] = asset;
  }
}

class _ProfileFileSystem implements AssetFileSystem {
  _ProfileFileSystem({
    this.delay = Duration.zero,
    this.missingPaths = const <String>{},
  });

  final Duration delay;
  final Set<String> missingPaths;
  int calls = 0;
  int active = 0;
  int maxConcurrent = 0;

  @override
  Future<bool> exists(String path) async {
    calls++;
    active++;
    if (active > maxConcurrent) maxConcurrent = active;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    active--;
    return !missingPaths.contains(path);
  }

  @override
  Future<List<String>> filesUnder(String root) async => const [];
}
