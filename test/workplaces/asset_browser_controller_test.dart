import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/asset_availability_service.dart';
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
    final controller = _controller(repo);

    await controller.load('w1');

    expect(controller.state.loading, isFalse);
    expect(controller.state.assets.map((asset) => asset.id), ['a', 'b']);
  });

  test('selection is a single source of truth and survives refresh', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w1', 'b.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = _controller(repo);
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
    final controller = _controller(repo);
    await controller.load('w1');
    controller.select('a');

    await controller.load('w2');

    expect(controller.state.selectedAssetId, isNull);
    expect(controller.state.assets.single.id, 'b');
  });

  test('failed Workplace switch cannot retain previous assets', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
    ], failWorkplaceIds: {'w2'});
    final controller = _controller(repo);
    await controller.load('w1');
    controller.select('a');

    await controller.load('w2');

    expect(controller.state.workplaceId, 'w2');
    expect(controller.state.assets, isEmpty);
    expect(controller.state.selectedAssetId, isNull);
    expect(controller.state.errorMessage, isNotNull);
  });

  test('selects imported asset by effective path after refresh', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w1', 'b.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = _controller(repo);
    await controller.load('w1');

    expect(controller.selectByEffectivePath('/tmp/b.jpg'), isTrue);
    expect(controller.state.selectedAssetId, 'b');
    expect(controller.selectByEffectivePath('/tmp/missing.jpg'), isFalse);
    expect(controller.state.selectedAssetId, 'b');
  });

  test('availability scan persists missing state and recovery', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
    ]);
    final fs = _MemoryFileSystem(existing: const {});
    final controller = _controller(repo, fs: fs);
    await controller.load('w1');
    await controller.scanAvailability();

    expect(controller.state.assets.single.missing, isTrue);
    expect((await repo.getById('a'))?.missing, isTrue);

    fs.existing.add('/tmp/a.jpg');
    await controller.scanAvailability();
    expect(controller.state.assets.single.missing, isFalse);
    expect((await repo.getById('a'))?.missing, isFalse);
  });

  test('relinks one missing asset without changing catalog identity', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)).copyWith(missing: true),
    ]);
    final fs = _MemoryFileSystem(existing: {'/moved/a.jpg'});
    final controller = _controller(repo, fs: fs);
    await controller.load('w1');

    expect(await controller.relinkAsset('a', '/moved/a.jpg'), isTrue);
    final asset = controller.state.assets.single;
    expect(asset.id, 'a');
    expect(asset.sourcePath, '/moved/a.jpg');
    expect(asset.missing, isFalse);
  });

  test('batch relink scans folder once and matches by filename', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)).copyWith(missing: true),
      _asset('b', 'w1', 'b.jpg', DateTime.utc(2026, 8, 16, 2)).copyWith(missing: true),
    ]);
    final fs = _MemoryFileSystem(
      existing: {'/archive/a.jpg', '/archive/nested/b.jpg'},
      folders: {
        '/archive': ['/archive/a.jpg', '/archive/nested/b.jpg'],
      },
    );
    final controller = _controller(repo, fs: fs);
    await controller.load('w1');

    expect(await controller.relinkMissingFromFolder('/archive'), 2);
    expect(controller.state.missingCount, 0);
    expect(fs.folderScans, 1);
  });

  test('remove from Workplace deletes catalog record only', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'a.jpg', DateTime.utc(2026, 8, 16, 1)),
    ]);
    final fs = _MemoryFileSystem(existing: {'/tmp/a.jpg'});
    final controller = _controller(repo, fs: fs);
    await controller.load('w1');
    controller.select('a');

    await controller.removeFromWorkplace('a');

    expect(controller.state.assets, isEmpty);
    expect(controller.state.selectedAssetId, isNull);
    expect(await repo.getById('a'), isNull);
    expect(fs.existing, contains('/tmp/a.jpg'));
  });

  test('supports recent-first and filename sorting', () async {
    final repo = _MemoryAssetRepository([
      _asset('a', 'w1', 'Zulu.jpg', DateTime.utc(2026, 8, 16, 1)),
      _asset('b', 'w1', 'alpha.jpg', DateTime.utc(2026, 8, 16, 2)),
    ]);
    final controller = _controller(repo);
    await controller.load('w1');

    controller.setSortOrder(AssetSortOrder.importedDescending);
    expect(controller.state.assets.first.id, 'b');

    controller.setSortOrder(AssetSortOrder.nameAscending);
    expect(controller.state.assets.first.id, 'b');
  });
}

AssetBrowserController _controller(
  AssetRepository repo, {
  _MemoryFileSystem? fs,
}) {
  return AssetBrowserController(
    assetRepository: repo,
    availabilityService: AssetAvailabilityService(
      fs ?? _MemoryFileSystem(existing: {'/tmp/a.jpg', '/tmp/b.jpg', '/tmp/x.jpg', '/tmp/Zulu.jpg', '/tmp/alpha.jpg'}),
    ),
  );
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

class _MemoryFileSystem implements AssetFileSystem {
  _MemoryFileSystem({
    required Set<String> existing,
    Map<String, List<String>> folders = const {},
  })  : existing = {...existing},
        folders = {...folders};

  final Set<String> existing;
  final Map<String, List<String>> folders;
  int folderScans = 0;

  @override
  Future<bool> exists(String path) async => existing.contains(path);

  @override
  Future<List<String>> filesUnder(String root) async {
    folderScans++;
    return folders[root] ?? const [];
  }
}

class _MemoryAssetRepository implements AssetRepository {
  _MemoryAssetRepository(
    Iterable<AssetRecord> assets, {
    Set<String> failWorkplaceIds = const {},
  })  : _assets = {for (final asset in assets) asset.id: asset},
        _failWorkplaceIds = failWorkplaceIds;

  final Map<String, AssetRecord> _assets;
  final Set<String> _failWorkplaceIds;

  @override
  Future<void> delete(String id) async => _assets.remove(id);

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    _assets.removeWhere((_, asset) => asset.workplaceId == workplaceId);
  }

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async {
    if (_failWorkplaceIds.contains(workplaceId)) {
      throw StateError('failed to load $workplaceId');
    }
    return _assets.values
        .where((asset) => asset.workplaceId == workplaceId)
        .toList();
  }

  @override
  Future<AssetRecord?> getById(String id) async => _assets[id];

  @override
  Future<void> save(AssetRecord asset) async {
    _assets[asset.id] = asset;
  }
}
