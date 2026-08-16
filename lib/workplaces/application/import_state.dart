import '../domain/asset_record.dart';
import '../domain/import_batch.dart';

enum ImportPhase {
  idle,
  selecting,
  scanning,
  checkingDuplicates,
  copying,
  cataloging,
  completed,
  cancelled,
  failed,
}

class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.storageMode = AssetStorageMode.linked,
    this.total = 0,
    this.processed = 0,
    this.imported = 0,
    this.skippedDuplicates = 0,
    this.failed = 0,
    this.currentFile,
    this.lastImportedPath,
    this.batch,
    this.errorMessage,
  });

  final ImportPhase phase;
  final AssetStorageMode storageMode;
  final int total;
  final int processed;
  final int imported;
  final int skippedDuplicates;
  final int failed;
  final String? currentFile;
  final String? lastImportedPath;
  final ImportBatch? batch;
  final String? errorMessage;

  bool get busy => switch (phase) {
        ImportPhase.selecting ||
        ImportPhase.scanning ||
        ImportPhase.checkingDuplicates ||
        ImportPhase.copying ||
        ImportPhase.cataloging => true,
        _ => false,
      };

  double? get progress => total <= 0 ? null : processed / total;

  ImportState copyWith({
    ImportPhase? phase,
    AssetStorageMode? storageMode,
    int? total,
    int? processed,
    int? imported,
    int? skippedDuplicates,
    int? failed,
    String? currentFile,
    bool clearCurrentFile = false,
    String? lastImportedPath,
    bool clearLastImportedPath = false,
    ImportBatch? batch,
    bool clearBatch = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImportState(
      phase: phase ?? this.phase,
      storageMode: storageMode ?? this.storageMode,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      imported: imported ?? this.imported,
      skippedDuplicates: skippedDuplicates ?? this.skippedDuplicates,
      failed: failed ?? this.failed,
      currentFile: clearCurrentFile ? null : currentFile ?? this.currentFile,
      lastImportedPath: clearLastImportedPath
          ? null
          : lastImportedPath ?? this.lastImportedPath,
      batch: clearBatch ? null : batch ?? this.batch,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
