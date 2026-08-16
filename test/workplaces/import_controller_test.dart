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
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('imports supported files into active workplace and persists batch', () async {
    final file = File('${tempDir.path}/sample.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final controller = _controller(assets, batches, preferences);

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
    expect(batches.values.single.sourcePaths, [file.absolute.path]);
    expect(batches.values.single.failedPaths, isEmpty);
  });

  test('skips duplicate source paths in the same workplace', () async {
    final file = File('${tempDir.path}/duplicate.nef');
    await file.writeAsBytes([1, 2, 3]);
    final controller = _controller(assets, batches, preferences);

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
    final controller = _controller(assets, batches, preferences);

    await controller.importPaths([source.path], sourceType: ImportSourceType.files);

    final asset = assets.values.single;
    expect(asset.storageMode, AssetStorageMode.managed);
    expect(asset.managedPath, isNotNull);
    expect(await File(asset.managedPath!).exists(), isTrue);
    expect(await source.exists(), isTrue);
  });

  test('missing remembered managed destination is reselected, not recreated', () async {
    final source = File('${tempDir.path}/managed-reselect.jpg');
    await source.writeAsBytes([7, 8, 9]);
    final missingRoot = '${tempDir.path}/disconnected-volume';
    final replacement = Directory('${tempDir.path}/replacement-root');
    await replacement.create();
    preferences.mode = AssetStorageMode.managed;
    preferences.destination = missingRoot;
    var pickerCalls = 0;
    final controller = _controller(
      assets,
      batches,
      preferences,
      pickManagedDestination: () async {
        pickerCalls++;
        return replacement.path;
      },
    );

    await controller.importPaths([source.path], sourceType: ImportSourceType.files);

    expect(pickerCalls, 1);
    expect(await Directory(missingRoot).exists(), isFalse);
    expect(preferences.destination, replacement.absolute.path);
    expect(assets.values.single.managedPath, startsWith(replacement.absolute.path));
  });

  test('managed copy collision never overwrites an existing file', () async {
    final source = File('${tempDir.path}/collision.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final destination = Directory('${tempDir.path}/managed-root');
    await destination.create();
    preferences.mode = AssetStorageMode.managed;
    preferences.destination = destination.path;
    final fixedNow = DateTime.utc(2026, 8, 16, 12);
    final assetId = 'asset-${fixedNow.microsecondsSinceEpoch}-0';
    final dayFolder = Directory('${destination.path}/originals/2026/08/16');
    await dayFolder.create(recursive: true);
    final collision = File('${dayFolder.path}/$assetId-collision.jpg');
    await collision.writeAsBytes([99]);
    final controller = _controller(
      assets,
      batches,
      preferences,
      now: () => fixedNow,
    );

    await controller.importPaths([source.path], sourceType: ImportSourceType.files);

    expect(await collision.readAsBytes(), [99]);
    final managedPath = assets.values.single.managedPath!;
    expect(managedPath, isNot(collision.path));
    expect(await File(managedPath).readAsBytes(), [1, 2, 3]);
  });

  test('catalog failure cleans up a newly copied managed original', () async {
    final source = File('${tempDir.path}/catalog-failure.jpg');
    await source.writeAsBytes([1, 2, 3]);
    final destination = Directory('${tempDir.path}/managed-root');
    await destination.create();
    preferences.mode = AssetStorageMode.managed;
    preferences.destination = destination.path;
    assets.failNextSave = true;
    final controller = _controller(assets, batches, preferences);

    await controller.importPaths([source.path], sourceType: ImportSourceType.files);

    expect(controller.state.phase.name, 'failed');
    expect(controller.state.failed, 1);
    expect(assets.values, isEmpty);
    final copiedFiles = await destination
        .list(recursive: true)
        .where((entity) => entity is File)
        .toList();
    expect(copiedFiles, isEmpty);
    expect(await source.exists(), isTrue);
  });

  test('failed batch can retry without duplicating prior successes', () async {
    final successful = File('${tempDir.path}/successful.jpg');
    final initiallyMissing = File('${tempDir.path}/retry.jpg');
    await successful.writeAsBytes([1]);
    final controller = _controller(assets, batches, preferences);

    await controller.importPaths(
      [successful.path, initiallyMissing.path],
      sourceType: ImportSourceType.files,
    );

    final firstBatch = controller.state.batch!;
    expect(controller.state.phase.name, 'completed');
    expect(firstBatch.importedCount, 1);
    expect(firstBatch.failedCount, 1);
    expect(firstBatch.failedPaths, [initiallyMissing.absolute.path]);
    expect(assets.values, hasLength(1));

    await initiallyMissing.writeAsBytes([2]);
    expect(await controller.retryBatch(firstBatch.id), isTrue);

    expect(assets.values, hasLength(2));
    expect(
      assets.values.map((asset) => asset.sourcePath).toSet(),
      {successful.absolute.path, initiallyMissing.absolute.path},
    );
  });

  test('retry preserves configured storage mode after using batch override', () async {
    final source = File('${tempDir.path}/retry-mode.jpg');
    await source.writeAsBytes([1]);
    preferences.mode = AssetStorageMode.managed;
    final batch = ImportBatch(
      id: 'linked-retry',
      workplaceId: 'workplace-1',
      startedAt: DateTime.utc(2026, 8, 16),
      sourceType: ImportSourceType.files,
      storageMode: AssetStorageMode.linked,
      requestedCount: 1,
      importedCount: 0,
      skippedDuplicateCount: 0,
      failedCount: 1,
      status: ImportBatchStatus.failed,
      sourcePaths: [source.absolute.path],
      failedPaths: [source.absolute.path],
    );
    await batches.save(batch);
    final controller = _controller(assets, batches, preferences);

    expect(controller.state.storageMode, AssetStorageMode.managed);
    expect(await controller.retryBatch(batch.id), isTrue);
    expect(controller.state.storageMode, AssetStorageMode.managed);
    expect(assets.values.single.storageMode, AssetStorageMode.linked);
  });

  test('restores latest persisted recoverable batch after restart', () async {
    final source = File('${tempDir.path}/interrupted.jpg');
    final older = ImportBatch(
      id: 'older',
      workplaceId: 'workplace-1',
      startedAt: DateTime.utc(2026, 8, 16, 8),
      sourceType: ImportSourceType.files,
      storageMode: AssetStorageMode.linked,
      requestedCount: 1,
      importedCount: 0,
      skippedDuplicateCount: 0,
      failedCount: 1,
      status: ImportBatchStatus.failed,
      sourcePaths: [source.absolute.path],
      failedPaths: [source.absolute.path],
    );
    final newer = ImportBatch(
      id: 'newer-running',
      workplaceId: 'workplace-1',
      startedAt: DateTime.utc(2026, 8, 16, 9),
      sourceType: ImportSourceType.files,
      storageMode: AssetStorageMode.managed,
      requestedCount: 1,
      importedCount: 0,
      skippedDuplicateCount: 0,
      failedCount: 0,
      status: ImportBatchStatus.running,
      sourcePaths: [source.absolute.path],
    );
    await batches.save(older);
    await batches.save(newer);
    final controller = _controller(assets, batches, preferences);

    await controller.restoreLatestRecoverableBatch('workplace-1');

    expect(controller.state.batch?.id, 'newer-running');
    expect(controller.state.batch?.canRetry, isTrue);
    expect(controller.state.phase, ImportPhase.failed);
    expect(controller.state.failed, 1);
    expect(controller.state.storageMode, preferences.mode);
  });

  test('retry requires the original Workplace and clears stale open path', () async {
    final missing = File('${tempDir.path}/missing.jpg');
    var workplace = 'workplace-1';
    final controller = ImportController(
      assetRepository: assets,
      importRepository: batches,
      preferences: preferences,
      currentWorkplaceId: () => workplace,
    );
    await controller.importPaths([missing.path], sourceType: ImportSourceType.files);
    final batch = controller.state.batch!;
    workplace = 'workplace-2';

    expect(await controller.retryBatch(batch.id), isFalse);
    expect(controller.state.phase.name, 'failed');
    expect(controller.state.errorMessage, contains('original Workplace'));
    expect(controller.state.lastImportedPath, isNull);
  });

  test('old ImportBatch maps remain readable without recovery path fields', () {
    final batch = ImportBatch.fromMap({
      'id': 'legacy',
      'workplaceId': 'w1',
      'startedAt': DateTime.utc(2026).toIso8601String(),
      'completedAt': null,
      'sourceType': 'files',
      'sourceRoot': null,
      'requestedCount': 1,
      'importedCount': 1,
      'skippedDuplicateCount': 0,
      'failedCount': 0,
      'status': 'completed',
    });

    expect(batch.sourcePaths, isEmpty);
    expect(batch.failedPaths, isEmpty);
    expect(batch.storageMode, AssetStorageMode.linked);
    expect(batch.canRetry, isFalse);
  });

  test('unsupported files are filtered without creating catalog records', () async {
    final file = File('${tempDir.path}/notes.txt');
    await file.writeAsString('not an image');
    final controller = _controller(assets, batches, preferences);

    await controller.importPaths([file.path], sourceType: ImportSourceType.files);

    expect(assets.values, isEmpty);
    expect(controller.state.total, 0);
    expect(controller.state.imported, 0);
  });
}

ImportController _controller(
  _MemoryAssetRepository assets,
  _MemoryImportRepository batches,
  _MemoryImportPreferences preferences, {
  DateTime Function()? now,
  Future<String?> Function()? pickManagedDestination,
}) {
  return ImportController(
    assetRepository: assets,
    importRepository: batches,
    preferences: preferences,
    currentWorkplaceId: () => 'workplace-1',
    now: now,
    pickManagedDestination: pickManagedDestination,
  );
}

class _MemoryAssetRepository implements AssetRepository {
  final Map<String, AssetRecord> _assets = {};
  bool failNextSave = false;
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
    if (failNextSave) {
      failNextSave = false;
      throw StateError('catalog write failed');
    }
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
