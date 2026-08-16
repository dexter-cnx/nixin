enum ImportSourceType { files, folder }

enum ImportBatchStatus { running, completed, cancelled, failed }

class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.workplaceId,
    required this.startedAt,
    required this.sourceType,
    required this.requestedCount,
    required this.importedCount,
    required this.skippedDuplicateCount,
    required this.failedCount,
    required this.status,
    this.sourceRoot,
    this.completedAt,
  });

  final String id;
  final String workplaceId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final ImportSourceType sourceType;
  final String? sourceRoot;
  final int requestedCount;
  final int importedCount;
  final int skippedDuplicateCount;
  final int failedCount;
  final ImportBatchStatus status;

  Map<String, Object?> toMap() => {
        'id': id,
        'workplaceId': workplaceId,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'sourceType': sourceType.name,
        'sourceRoot': sourceRoot,
        'requestedCount': requestedCount,
        'importedCount': importedCount,
        'skippedDuplicateCount': skippedDuplicateCount,
        'failedCount': failedCount,
        'status': status.name,
      };

  factory ImportBatch.fromMap(Map<dynamic, dynamic> map) => ImportBatch(
        id: map['id'] as String,
        workplaceId: map['workplaceId'] as String,
        startedAt: DateTime.parse(map['startedAt'] as String),
        completedAt: map['completedAt'] == null
            ? null
            : DateTime.parse(map['completedAt'] as String),
        sourceType: ImportSourceType.values.byName(map['sourceType'] as String),
        sourceRoot: map['sourceRoot'] as String?,
        requestedCount: map['requestedCount'] as int,
        importedCount: map['importedCount'] as int,
        skippedDuplicateCount: map['skippedDuplicateCount'] as int,
        failedCount: map['failedCount'] as int,
        status: ImportBatchStatus.values.byName(map['status'] as String),
      );
}
