import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/asset_browser_controller.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/asset_repository.dart';

void main() {
  test('loads only assets from the active Workplace in import order', () async {
    final repo = _MemoryAssetRepository([
      _asset('b', 'w1', 'b.jpg', DateTime.utc(2026, 8, 16, 2)),
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('x', 'w2', 'x.jpg', DateTime.utc(2026, 8, 16, 0)),
    ]);
    final controller = AssetBrowserController(assetRepository: repo);

    await controller.load('w1');

    expect(controller.state.loading, isFalse);
    expect(controller.state.assets.map((asset) => asset.id), ['a', 'b']);
  });

  test('selection is a single source of truth and survives refresh', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w1', 'b.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = AssetBrowserController(assetRepository: repo);
    await controller.load('w1');

    controller.select('b');
    await controller.refresh();

    expect(controller.state.selectedAssetId, 'b');
    expect(controller.state.selectedAsset?.originalFilename, 'b.jpg');
  });

  test('switching Workplace clears incompatible selection', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w2', 'b.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = AssetBrowserController(assetRepository: repo);
    await controller.load('w1');
    controller.select('a');

    await controller.load('w2');

    expect(controller.state.selectedAssetId, isNull);
    expect(controller.state.assets.single.id, 'b');
  });

  test('supports recent-first and filename sorting', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'Zulu.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w1', 'alpha.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = AssetBrowserController(assetRepository: repo);
    await controller.load('w1');

    controller.setSortOrder(AssetSortOrder.importedDescending);
    expect(controller.state.assets.first.id, 'b');

    controller.setSortOrder(AssetSortOrder.nameAscending);
    expect(controller.state.assets.first.id, 'b');
  });
}

AssetRecord _asset(
  String id,
  String workplaceId,
  String name,
  DateTime importedAt,
) {
  return AssetRecord(
    id: id,
    workplaceId: workplaceId,
    originalFilename: name,
    sourcePath: '/tmp/$name',
    storageMode: AssetStorageMode.linked,
    mediaType: AssetMediaType.raster,
    format: 'jpg',
    fileSize: 10,
    importedAt: importedAt,
    modifiedAt: importedAt,
  );
}

class _MemoryAssetRepository implements AssetRepository {
  _MemoryAssetRepository(Iterable<AssetRecord> assets)
      : _assets = {for (final asset in assets) asset.id: asset};

  final Map<String, AssetRecord> _assets;

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
    _assets[asset.id] = asset;
  }
}
