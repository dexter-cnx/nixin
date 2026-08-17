import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../storage/app_storage.dart';
import '../../storage/storage_providers.dart';
import '../data/hive/hive_import_repository.dart';
import '../domain/asset_record.dart';
import '../domain/import_batch.dart';
import '../domain/repositories/asset_repository.dart';
import '../domain/repositories/import_repository.dart';
import 'import_state.dart';
import 'workplace_controller.dart';

abstract interface class ImportPreferences {
  AssetStorageMode readStorageMode();
  String? readManagedDestination();
  Future<void> writeStorageMode(AssetStorageMode mode);
  Future<void> writeManagedDestination(String path);
}

class KeyValueImportPreferences implements ImportPreferences {
  KeyValueImportPreferences(this._store);

  final KeyValueStore _store;

  @override
  AssetStorageMode readStorageMode() {
    final value = _store.read(
      'importStorageMode',
      defaultValue: 'linked',
    ) as String;
    return AssetStorageMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetStorageMode.linked,
    );
  }

  @override
  String? readManagedDestination() =>
      _store.read('managedImportDestination') as String?;

  @override
  Future<void> writeStorageMode(AssetStorageMode mode) =>
      _store.write('importStorageMode', mode.name);

  @override
  Future<void> writeManagedDestination(String path) =>
      _store.write('managedImportDestination', path);
}

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return HiveImportRepository(ref.watch(importBatchesStoreProvider));
});

final importPreferencesProvider = Provider<ImportPreferences>((ref) {
  return KeyValueImportPreferences(ref.watch(settingsStoreProvider));
});

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>((ref) {
  final controller = ImportController(
    assetRepository: ref.watch(assetRepositoryProvider),
    importRepository: ref.watch(importRepositoryProvider),
    preferences: ref.watch(importPreferencesProvider),
    currentWorkplaceId: () =>
        ref.read(workplaceControllerProvider).currentWorkplaceId,
  );

  ref.listen<String?>(
    workplaceControllerProvider.select((state) => state.currentWorkplaceId),
    (_, workplaceId) =>
        unawaited(controller.restoreLatestRecoverableBatch(workplaceId)),
    fireImmediately: true,
  );

  return controller;
});

class ImportController extends StateNotifier<ImportState> {
  ImportController({
    required AssetRepository assetRepository,
    required ImportRepository importRepository,
    required ImportPreferences preferences,
    required String? Function() currentWorkplaceId,
    DateTime Function()? now,
    Future<String?> Function()? pickManagedDestination,
  })  : _assetRepository = assetRepository,
        _importRepository = importRepository,
        _preferences = preferences,
        _currentWorkplaceId = currentWorkplaceId,
        _now = now ?? DateTime.now,
        _pickManagedDestination = pickManagedDestination ??
            (() => FilePicker.platform.getDirectoryPath(
                  dialogTitle: 'Choose managed originals location',
                )),
        super(ImportState(storageMode: preferences.readStorageMode()));

  static const supportedExtensions = <String>{
    'arw', 'cr2', 'cr3', 'nef', 'dng', 'raf', 'orf',
    'jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp', 'gif',
  };

  static const rawExtensions = <String>{
    'arw', 'cr2', 'cr3', 'nef', 'dng', 'raf', 'orf',
  };

  final AssetRepository _assetRepository;
  final ImportRepository _importRepository;
  final ImportPreferences _preferences;
  final String? Function() _currentWorkplaceId;
  final DateTime Function() _now;
  final Future<String?> Function() _pickManagedDestination;

  bool _cancelRequested = false;
  int _restoreRevision = 0;

  Future<void> setStorageMode(AssetStorageMode mode) async {
    state = state.copyWith(storageMode: mode);
    await _preferences.writeStorageMode(mode);
  }

  void cancel() {
    if (state.busy) _cancelRequested = true;
  }

  Future<void> restoreLatestRecoverableBatch(String? workplaceId) async {
    final revision = ++_restoreRevision;
    if (state.busy) return;
    if (workplaceId == null) {
      state = state.copyWith(clearBatch: true, clearError: true);
      return;
    }

    final batches = await _importRepository.getByWorkplace(workplaceId);
    if (revision != _restoreRevision || state.busy) return;
    final recoverable = batches.where((batch) => batch.canRetry).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (recoverable.isEmpty) {
      state = state.copyWith(clearBatch: true, clearError: true);
      return;
    }

    final batch = recoverable.first;
    final attentionCount = batch.failedPaths.isNotEmpty
        ? batch.failedPaths.length
        : batch.sourcePaths.length;
    state = state.copyWith(
      phase: ImportPhase.failed,
      total: batch.requestedCount,
      processed: batch.importedCount + batch.skippedDuplicateCount,
      imported: batch.importedCount,
      skippedDuplicates: batch.skippedDuplicateCount,
      failed: attentionCount,
      batch: batch,
      clearCurrentFile: true,
      clearLastImportedPath: true,
      errorMessage: 'Recoverable import found',
    );
  }

  Future<void> importFiles() async {
    if (state.busy) return;
    ++_restoreRevision;
    _cancelRequested = false;
    state = state.copyWith(
      phase: ImportPhase.selecting,
      clearError: true,
      clearLastImportedPath: true,
    );
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList(growable: false),
    );
    final paths =
        result?.files.map((file) => file.path).whereType<String>().toList();
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }
    if (paths == null || paths.isEmpty) {
      state = state.copyWith(phase: ImportPhase.idle);
      return;
    }
    await importPaths(
      paths,
      sourceType: ImportSourceType.files,
      preserveCancellation: true,
    );
  }

  Future<void> importFolder({bool recursive = true}) async {
    if (state.busy) return;
    ++_restoreRevision;
    _cancelRequested = false;
    state = state.copyWith(
      phase: ImportPhase.selecting,
      clearError: true,
      clearLastImportedPath: true,
    );
    final root = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to import',
    );
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }
    if (root == null) {
      state = state.copyWith(phase: ImportPhase.idle);
      return;
    }

    state = state.copyWith(phase: ImportPhase.scanning);
    final paths = <String>[];
    try {
      await for (final entity in Directory(root).list(
        recursive: recursive,
        followLinks: false,
      )) {
        if (_cancelRequested) break;
        if (entity is File && isSupported(entity.path)) paths.add(entity.path);
      }
    } catch (error) {
      state = state.copyWith(phase: ImportPhase.failed, errorMessage: '$error');
      return;
    }
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }
    await importPaths(
      paths,
      sourceType: ImportSourceType.folder,
      sourceRoot: root,
      preserveCancellation: true,
    );
  }

  Future<bool> retryBatch(String batchId) async {
    if (state.busy) return false;
    ++_restoreRevision;
    final batch = await _importRepository.getById(batchId);
    if (batch == null || !batch.canRetry) return false;
    final workplaceId = _currentWorkplaceId();
    if (workplaceId != batch.workplaceId) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        clearLastImportedPath: true,
        errorMessage: 'Switch to the original Workplace before retrying import',
      );
      return false;
    }
    final paths = batch.failedPaths.isNotEmpty
        ? batch.failedPaths
        : batch.sourcePaths;
    if (paths.isEmpty) return false;
    await importPaths(
      paths,
      sourceType: batch.sourceType,
      sourceRoot: batch.sourceRoot,
      storageModeOverride: batch.storageMode,
    );
    return state.phase == ImportPhase.completed;
  }

  Future<void> importPaths(
    List<String> paths, {
    required ImportSourceType sourceType,
    String? sourceRoot,
    bool preserveCancellation = false,
    AssetStorageMode? storageModeOverride,
  }) async {
    ++_restoreRevision;
    final workplaceId = _currentWorkplaceId();
    if (workplaceId == null) {
      state = state.copyWith(
        phase: ImportPhase.failed,
        errorMessage: 'No active Workplace',
      );
      return;
    }

    if (!preserveCancellation) _cancelRequested = false;
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }

    final candidates = paths
        .where(isSupported)
        .map((path) => p.normalize(p.absolute(path)))
        .toList(growable: false);
    final startedAt = _now();
    final batchId = 'import-${startedAt.microsecondsSinceEpoch}';
    final configuredStorageMode = state.storageMode;
    final selectedStorageMode = storageModeOverride ?? configuredStorageMode;
    state = ImportState(
      phase: ImportPhase.checkingDuplicates,
      storageMode: configuredStorageMode,
      total: candidates.length,
    );

    final existing = await _assetRepository.getByWorkplace(workplaceId);
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }
    final known = existing.map((asset) => canonicalPath(asset.sourcePath)).toSet();

    String? managedRoot;
    if (selectedStorageMode == AssetStorageMode.managed) {
      managedRoot = await _resolveManagedRoot();
      if (_cancelRequested) {
        state = state.copyWith(phase: ImportPhase.cancelled);
        return;
      }
      if (managedRoot == null) {
        state = state.copyWith(
          phase: ImportPhase.failed,
          errorMessage: 'Managed originals location is unavailable',
        );
        return;
      }
    }

    await _importRepository.save(ImportBatch(
      id: batchId,
      workplaceId: workplaceId,
      startedAt: startedAt,
      sourceType: sourceType,
      storageMode: selectedStorageMode,
      sourceRoot: sourceRoot,
      requestedCount: candidates.length,
      importedCount: 0,
      skippedDuplicateCount: 0,
      failedCount: 0,
      status: ImportBatchStatus.running,
      sourcePaths: candidates,
    ));

    var imported = 0;
    var skipped = 0;
    var failed = 0;
    String? lastImportedPath;
    final failedPaths = <String>[];

    for (var index = 0; index < candidates.length; index++) {
      if (_cancelRequested) break;
      final source = candidates[index];
      final canonical = canonicalPath(source);
      if (known.contains(canonical)) {
        skipped++;
        state = state.copyWith(
          processed: index + 1,
          skippedDuplicates: skipped,
          currentFile: p.basename(source),
        );
        continue;
      }

      String? newlyCopiedManagedPath;
      try {
        final file = File(source);
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) {
          throw StateError('Not a file');
        }
        final importedAt = _now();
        final assetId = await _uniqueAssetId(importedAt, index);
        String? managedPath;

        if (selectedStorageMode == AssetStorageMode.managed) {
          state = state.copyWith(
            phase: ImportPhase.copying,
            currentFile: p.basename(source),
          );
          managedPath = await _copyManagedOriginal(
            file: file,
            managedRoot: managedRoot!,
            assetId: assetId,
            importedAt: importedAt,
          );
          newlyCopiedManagedPath = managedPath;
        }

        if (_cancelRequested) {
          if (newlyCopiedManagedPath != null) {
            await _deleteIfExists(newlyCopiedManagedPath);
          }
          break;
        }
        state = state.copyWith(
          phase: ImportPhase.cataloging,
          currentFile: p.basename(source),
        );
        final extension = p.extension(source).replaceFirst('.', '').toLowerCase();
        final asset = AssetRecord(
          id: assetId,
          workplaceId: workplaceId,
          originalFilename: p.basename(source),
          sourcePath: source,
          managedPath: managedPath,
          storageMode: selectedStorageMode,
          mediaType: rawExtensions.contains(extension)
              ? AssetMediaType.raw
              : AssetMediaType.raster,
          format: extension,
          fileSize: stat.size,
          importedAt: importedAt,
          modifiedAt: stat.modified,
          importBatchId: batchId,
        );
        try {
          await _assetRepository.save(asset);
        } catch (_) {
          if (newlyCopiedManagedPath != null) {
            await _deleteIfExists(newlyCopiedManagedPath);
          }
          rethrow;
        }
        known.add(canonical);
        imported++;
        lastImportedPath = asset.effectivePath;
      } catch (_) {
        failed++;
        failedPaths.add(source);
      }

      state = state.copyWith(
        processed: index + 1,
        imported: imported,
        skippedDuplicates: skipped,
        failed: failed,
        lastImportedPath: lastImportedPath,
      );
      await Future<void>.delayed(Duration.zero);
    }

    final cancelled = _cancelRequested;
    final completedAt = _now();
    final batch = ImportBatch(
      id: batchId,
      workplaceId: workplaceId,
      startedAt: startedAt,
      completedAt: completedAt,
      sourceType: sourceType,
      storageMode: selectedStorageMode,
      sourceRoot: sourceRoot,
      requestedCount: candidates.length,
      importedCount: imported,
      skippedDuplicateCount: skipped,
      failedCount: failed,
      status: cancelled
          ? ImportBatchStatus.cancelled
          : failed > 0 && imported == 0
              ? ImportBatchStatus.failed
              : ImportBatchStatus.completed,
      sourcePaths: candidates,
      failedPaths: failedPaths,
    );
    await _importRepository.save(batch);
    state = state.copyWith(
      phase: cancelled
          ? ImportPhase.cancelled
          : failed > 0 && imported == 0
              ? ImportPhase.failed
              : ImportPhase.completed,
      processed: cancelled ? state.processed : candidates.length,
      imported: imported,
      skippedDuplicates: skipped,
      failed: failed,
      batch: batch,
      clearCurrentFile: true,
      lastImportedPath: lastImportedPath,
      errorMessage: failed > 0 && imported == 0 ? 'Import failed' : null,
    );
  }

  Future<String?> _resolveManagedRoot() async {
    final remembered = _preferences.readManagedDestination();
    if (remembered != null && remembered.isNotEmpty) {
      final normalized = p.normalize(p.absolute(remembered));
      if (await Directory(normalized).exists()) return normalized;
    }

    final selected = await _pickManagedDestination();
    if (selected == null || selected.isEmpty) return null;
    final normalized = p.normalize(p.absolute(selected));
    if (!await Directory(normalized).exists()) return null;
    await _preferences.writeManagedDestination(normalized);
    return normalized;
  }

  Future<String> _uniqueAssetId(DateTime importedAt, int index) async {
    final base = 'asset-${importedAt.microsecondsSinceEpoch}-$index';
    if (await _assetRepository.getById(base) == null) return base;
    var suffix = 1;
    while (await _assetRepository.getById('$base-$suffix') != null) {
      suffix++;
    }
    return '$base-$suffix';
  }

  Future<Directory> _managedDayFolder(
    String managedRoot,
    DateTime importedAt,
  ) async {
    final root = Directory(managedRoot);
    if (!await root.exists()) {
      throw FileSystemException(
        'Managed originals location is unavailable',
        managedRoot,
      );
    }

    var current = root;
    for (final segment in [
      'originals',
      importedAt.year.toString().padLeft(4, '0'),
      importedAt.month.toString().padLeft(2, '0'),
      importedAt.day.toString().padLeft(2, '0'),
    ]) {
      if (!await root.exists()) {
        throw FileSystemException(
          'Managed originals location disconnected during import',
          managedRoot,
        );
      }
      final child = Directory(p.join(current.path, segment));
      if (!await child.exists()) {
        await child.create(recursive: false);
      }
      current = child;
    }
    return current;
  }

  Future<String> _copyManagedOriginal({
    required File file,
    required String managedRoot,
    required String assetId,
    required DateTime importedAt,
  }) async {
    final folder = await _managedDayFolder(managedRoot, importedAt);
    if (!await Directory(managedRoot).exists()) {
      throw FileSystemException(
        'Managed originals location disconnected during import',
        managedRoot,
      );
    }

    final baseName = '$assetId-${p.basename(file.path)}';
    var destination = p.join(folder.path, baseName);
    var suffix = 1;
    while (await File(destination).exists()) {
      destination = p.join(folder.path, '$baseName-$suffix');
      suffix++;
    }

    final partial = '$destination.partial';
    await _deleteIfExists(partial);
    try {
      if (!await Directory(managedRoot).exists()) {
        throw FileSystemException(
          'Managed originals location disconnected during import',
          managedRoot,
        );
      }
      final copied = await file.copy(partial);
      await copied.rename(destination);
      return destination;
    } catch (_) {
      await _deleteIfExists(partial);
      rethrow;
    }
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static bool isSupported(String path) {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    return supportedExtensions.contains(extension);
  }

  static String canonicalPath(String path) => p.normalize(p.absolute(path));
}
