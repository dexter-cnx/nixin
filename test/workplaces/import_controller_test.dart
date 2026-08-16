import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/import_controller.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/import_batch.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/asset_repository.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/import_repository.dart';

void main() {
  late Directory tempDir;
  late _MemoryAssetRepository assets;
  late _MemoryImportRepository batches;
  late _MemoryImportPreferences preferences;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nixin-import-test-');
    assets = _MemoryAssetRepository();
    batches = _MemoryImportRepository();
    preferences = _MemoryImportPreferences();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('imports supported files into active workplace and persists batch', () async {
    final file = File('${tempDir.path}/sample.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final controller = ImportController(
      assetRepository: assets,
      importRepository: batches,
      preferences: preferences,
      currentWorkplaceId: () => 'workplace-1',
    );

    await controller.importPaths(
      [file.path],
      sourceType: ImportSourceType.files,
    );

    expect(controller.state.phase.name, 'completed');
    expect(controller.state.imported, 1);
    expect(controller.state.failed, 0);
    expect(assets.values, hasLength(1));
    expect(assets.values.single.workplaceId, 'workplace-1');
    expect(assets.values.single.mediaType, AssetMediaType.raster);
    expect(batches.values, hasLength(1));
    expect(batches.values.single.importedCount, 1);
  });

  test('skips duplicate source paths in the same workplace', () async {
    final file = File('${tempDir.path}/duplicate.nef');
    await file.writeAsBytes([1, 2, 3]);
    final controller = ImportController(
      assetRepository: assets,
      importRepository: batches,
      preferences: preferences,
      currentWorkplaceId: () => 'workplace-1',
    );

    await controller.importPaths([file.path], sourceType: ImportSourceType.files);
    await controller.importPaths([file.path], sourceType: ImportSourceType.files);

    expect(assets.values, hasLength(1));
    expect(controller.state.imported, 0);
    expect(controller.state.skippedDuplicates, 1);
  });

  test('managed mode copies original and records managed path', () async {
    final source = File('${tempDir.path}/managed.png');
    await source.writeAsBytes([4, 5, 6]);
    final destination = Directory('${tempDir.path}/managed-root');
    await destination.create();
    preferences.mode = AssetStorageMode.managed;
    preferences.destination = destination.path;
    final controller = ImportController(
      assetRepository: assets,
      importRepository: batches,
      preferences: preferences,
      currentWorkplaceId: () => 'workplace-1',
    );

    await controller.importPaths([source.path], sourceType: ImportSourceType.files);

    final asset = assets.values.single;
    expect(asset.storageMode, AssetStorageMode.managed);
    expect(asset.managedPath, isNotNull);
    expect(await File(asset.managedPath!).exists(), isTrue);
    expect(await source.exists(), isTrue);
  });

  test('unsupported files are filtered without creating catalog records', () async {
    final file = File('${tempDir.path}/notes.txt');
    await file.writeAsString('not an image');
    final controller = ImportController(
      assetRepository: assets,
      importRepository: batches,
      preferences: preferences,
      currentWorkplaceId: () => 'workplace-1',
    );

    await controller.importPaths([file.path], sourceType: ImportSourceType.files);

    expect(assets.values, isEmpty);
    expect(controller.state.total, 0);
    expect(controller.state.imported, 0);
  });
}

class _MemoryAssetRepository implements AssetRepository {
  final Map<String, AssetRecord> _assets = {};
  List<AssetRecord> get values => _assets.values.toList();

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

class _MemoryImportRepository implements ImportRepository {
  final Map<String, ImportBatch> _batches = {};
  List<ImportBatch> get values => _batches.values.toList();

  @override
  Future<List<ImportBatch>> getByWorkplace(String workplaceId) async =>
      _batches.values.where((batch) => batch.workplaceId == workplaceId).toList();

  @override
  Future<ImportBatch?> getById(String id) async => _batches[id];

  @override
  Future<void> save(ImportBatch batch) async {
    _batches[batch.id] = batch;
  }
}

class _MemoryImportPreferences implements ImportPreferences {
  AssetStorageMode mode = AssetStorageMode.linked;
  String? destination;

  @override
  String? readManagedDestination() => destination;

  @override
  AssetStorageMode readStorageMode() => mode;

  @override
  Future<void> writeManagedDestination(String path) async {
    destination = path;
  }

  @override
  Future<void> writeStorageMode(AssetStorageMode value) async {
    mode = value;
  }
}
