import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/import_batch.dart';

void main() {
  test('round-trips recovery paths and managed storage mode', () {
    final original = ImportBatch(
      id: 'batch-1',
      workplaceId: 'workplace-1',
      startedAt: DateTime.utc(2026, 8, 16),
      sourceType: ImportSourceType.files,
      storageMode: AssetStorageMode.managed,
      requestedCount: 2,
      importedCount: 1,
      skippedDuplicateCount: 0,
      failedCount: 1,
      status: ImportBatchStatus.completed,
      sourcePaths: const ['/source/a.jpg', '/source/b.jpg'],
      failedPaths: const ['/source/b.jpg'],
    );

    final restored = ImportBatch.fromMap(original.toMap());

    expect(restored.storageMode, AssetStorageMode.managed);
    expect(restored.sourcePaths, original.sourcePaths);
    expect(restored.failedPaths, original.failedPaths);
    expect(restored.canRetry, isTrue);
  });

  test('legacy map defaults to linked and non-recoverable paths', () {
    final restored = ImportBatch.fromMap({
      'id': 'legacy',
      'workplaceId': 'workplace-1',
      'startedAt': DateTime.utc(2026, 8, 16).toIso8601String(),
      'completedAt': DateTime.utc(2026, 8, 16, 1).toIso8601String(),
      'sourceType': 'files',
      'sourceRoot': null,
      'requestedCount': 1,
      'importedCount': 1,
      'skippedDuplicateCount': 0,
      'failedCount': 0,
      'status': 'completed',
    });

    expect(restored.storageMode, AssetStorageMode.linked);
    expect(restored.sourcePaths, isEmpty);
    expect(restored.failedPaths, isEmpty);
    expect(restored.canRetry, isFalse);
  });
}
