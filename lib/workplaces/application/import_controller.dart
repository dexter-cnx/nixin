import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;

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

class HiveImportPreferences implements ImportPreferences {
  HiveImportPreferences(this._box);
  final Box<dynamic> _box;

  @override
  AssetStorageMode readStorageMode() {
    final value = _box.get('importStorageMode', defaultValue: 'linked') as String;
    return AssetStorageMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetStorageMode.linked,
    );
  }

  @override
  String? readManagedDestination() =>
      _box.get('managedImportDestination') as String?;

  @override
  Future<void> writeStorageMode(AssetStorageMode mode) =>
      _box.put('importStorageMode', mode.name);

  @override
  Future<void> writeManagedDestination(String path) =>
      _box.put('managedImportDestination', path);
}

final importBatchesBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('import_batches');
});

final importRepositoryProvider = Provider<ImportRepository>((ref) {
  return HiveImportRepository(ref.watch(importBatchesBoxProvider));
});

final importPreferencesProvider = Provider<ImportPreferences>((ref) {
  return HiveImportPreferences(ref.watch(workplaceSettingsBoxProvider));
});

final importControllerProvider =
    StateNotifierProvider<ImportController, ImportState>((ref) {
  return ImportController(
    assetRepository: ref.watch(assetRepositoryProvider),
    importRepository: ref.watch(importRepositoryProvider),
    preferences: ref.watch(importPreferencesProvider),
    currentWorkplaceId: () =>
        ref.read(workplaceControllerProvider).currentWorkplaceId,
  );
});

class ImportController extends StateNotifier<ImportState> {
  ImportController({
    required AssetRepository assetRepository,
    required ImportRepository importRepository,
    required ImportPreferences preferences,
    required String? Function() currentWorkplaceId,
    DateTime Function()? now,
  })  : _assetRepository = assetRepository,
        _importRepository = importRepository,
        _preferences = preferences,
        _currentWorkplaceId = currentWorkplaceId,
        _now = now ?? DateTime.now,
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

  bool _cancelRequested = false;

  Future<void> setStorageMode(AssetStorageMode mode) async {
    state = state.copyWith(storageMode: mode);
    await _preferences.writeStorageMode(mode);
  }

  void cancel() {
    if (state.busy) _cancelRequested = true;
  }

  Future<void> importFiles() async {
    if (state.busy) return;
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
    final paths = result?.files.map((file) => file.path).whereType<String>().toList();
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

  Future<void> importPaths(
    List<String> paths, {
    required ImportSourceType sourceType,
    String? sourceRoot,
    bool preserveCancellation = false,
  }) async {
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
    final selectedStorageMode = state.storageMode;
    state = ImportState(
      phase: ImportPhase.checkingDuplicates,
      storageMode: selectedStorageMode,
      total: candidates.length,
    );

    final existing = await _assetRepository.getByWorkplace(workplaceId);
    if (_cancelRequested) {
      state = state.copyWith(phase: ImportPhase.cancelled);
      return;
    }
    final known = existing.map((asset) => canonicalPath(asset.sourcePath)).toSet();
    String? managedRoot = _preferences.readManagedDestination();
    if (selectedStorageMode == AssetStorageMode.managed && managedRoot == null) {
      managedRoot = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose managed originals location',
      );
      if (_cancelRequested || managedRoot == null) {
        state = state.copyWith(phase: ImportPhase.cancelled);
        return;
      }
      await _preferences.writeManagedDestination(managedRoot);
    }

    var imported = 0;
    var skipped = 0;
    var failed = 0;
    String? lastImportedPath;

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

      try {
        final file = File(source);
        final stat = await file.stat();
        if (stat.type != FileSystemEntityType.file) throw StateError('Not a file');
        final importedAt = _now();
        final assetId = 'asset-${importedAt.microsecondsSinceEpoch}-$index';
        String? managedPath;

        if (selectedStorageMode == AssetStorageMode.managed) {
          state = state.copyWith(
            phase: ImportPhase.copying,
            currentFile: p.basename(source),
          );
          final folder = Directory(p.join(
            managedRoot!,
            'originals',
            importedAt.year.toString().padLeft(4, '0'),
            importedAt.month.toString().padLeft(2, '0'),
            importedAt.day.toString().padLeft(2, '0'),
          ));
          await folder.create(recursive: true);
          managedPath = p.join(folder.path, '$assetId-${p.basename(source)}');
          await file.copy(managedPath);
        }

        if (_cancelRequested) break;
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
        await _assetRepository.save(asset);
        known.add(canonical);
        imported++;
        lastImportedPath = asset.effectivePath;
      } catch (_) {
        failed++;
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
      sourceRoot: sourceRoot,
      requestedCount: candidates.length,
      importedCount: imported,
      skippedDuplicateCount: skipped,
      failedCount: failed,
      status: cancelled ? ImportBatchStatus.cancelled : ImportBatchStatus.completed,
    );
    await _importRepository.save(batch);
    state = state.copyWith(
      phase: cancelled ? ImportPhase.cancelled : ImportPhase.completed,
      processed: cancelled ? state.processed : candidates.length,
      imported: imported,
      skippedDuplicates: skipped,
      failed: failed,
      batch: batch,
      clearCurrentFile: true,
      lastImportedPath: lastImportedPath,
    );
  }

  static bool isSupported(String path) {
    final extension = p.extension(path).replaceFirst('.', '').toLowerCase();
    return supportedExtensions.contains(extension);
  }

  static String canonicalPath(String path) => p.normalize(p.absolute(path));
}
