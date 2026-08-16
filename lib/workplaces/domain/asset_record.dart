enum AssetStorageMode { linked, managed }

enum AssetMediaType { raw, raster }

class AssetRecord {
  const AssetRecord({
    required this.id,
    required this.workplaceId,
    required this.originalFilename,
    required this.sourcePath,
    required this.storageMode,
    required this.mediaType,
    required this.format,
    required this.fileSize,
    required this.importedAt,
    required this.modifiedAt,
    this.managedPath,
    this.captureDate,
    this.thumbnailPath,
    this.previewPath,
    this.missing = false,
    this.importBatchId,
  });

  final String id;
  final String workplaceId;
  final String originalFilename;
  final String sourcePath;
  final String? managedPath;
  final AssetStorageMode storageMode;
  final AssetMediaType mediaType;
  final String format;
  final int fileSize;
  final DateTime importedAt;
  final DateTime modifiedAt;
  final DateTime? captureDate;
  final String? thumbnailPath;
  final String? previewPath;
  final bool missing;
  final String? importBatchId;

  String get effectivePath => managedPath ?? sourcePath;

  AssetRecord copyWith({
    String? sourcePath,
    String? managedPath,
    bool clearManagedPath = false,
    String? thumbnailPath,
    String? previewPath,
    bool? missing,
  }) {
    return AssetRecord(
      id: id,
      workplaceId: workplaceId,
      originalFilename: originalFilename,
      sourcePath: sourcePath ?? this.sourcePath,
      managedPath: clearManagedPath ? null : managedPath ?? this.managedPath,
      storageMode: storageMode,
      mediaType: mediaType,
      format: format,
      fileSize: fileSize,
      importedAt: importedAt,
      modifiedAt: modifiedAt,
      captureDate: captureDate,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      previewPath: previewPath ?? this.previewPath,
      missing: missing ?? this.missing,
      importBatchId: importBatchId,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'workplaceId': workplaceId,
        'originalFilename': originalFilename,
        'sourcePath': sourcePath,
        'managedPath': managedPath,
        'storageMode': storageMode.name,
        'mediaType': mediaType.name,
        'format': format,
        'fileSize': fileSize,
        'importedAt': importedAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'captureDate': captureDate?.toIso8601String(),
        'thumbnailPath': thumbnailPath,
        'previewPath': previewPath,
        'missing': missing,
        'importBatchId': importBatchId,
      };

  factory AssetRecord.fromMap(Map<dynamic, dynamic> map) {
    return AssetRecord(
      id: map['id'] as String,
      workplaceId: map['workplaceId'] as String,
      originalFilename: map['originalFilename'] as String,
      sourcePath: map['sourcePath'] as String,
      managedPath: map['managedPath'] as String?,
      storageMode: AssetStorageMode.values.byName(map['storageMode'] as String),
      mediaType: AssetMediaType.values.byName(map['mediaType'] as String),
      format: map['format'] as String,
      fileSize: map['fileSize'] as int,
      importedAt: DateTime.parse(map['importedAt'] as String),
      modifiedAt: DateTime.parse(map['modifiedAt'] as String),
      captureDate: map['captureDate'] == null
          ? null
          : DateTime.parse(map['captureDate'] as String),
      thumbnailPath: map['thumbnailPath'] as String?,
      previewPath: map['previewPath'] as String?,
      missing: map['missing'] as bool? ?? false,
      importBatchId: map['importBatchId'] as String?,
    );
  }
}
