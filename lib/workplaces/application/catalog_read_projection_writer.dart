import 'dart:io';

import '../domain/asset_record.dart';
import '../domain/repositories/asset_repository.dart';
import '../domain/repositories/workplace_repository.dart';

/// Writes a disposable read-only projection of the authoritative catalog.
///
/// Hive/repositories remain the persistence authority. This file is only a
/// replaceable cross-process read cache for the native desktop frontend.
class CatalogReadProjectionWriter {
  CatalogReadProjectionWriter({
    required WorkplaceRepository workplaceRepository,
    required AssetRepository assetRepository,
    File? projectionFile,
  })  : _workplaceRepository = workplaceRepository,
        _assetRepository = assetRepository,
        _projectionFile = projectionFile ?? defaultProjectionFile();

  static const schemaHeader = 'DXTR_CATALOG_READ\t1';
  static const projectionFilename = 'catalog-read-projection-v1.tsv';

  final WorkplaceRepository _workplaceRepository;
  final AssetRepository _assetRepository;
  final File _projectionFile;

  File get projectionFile => _projectionFile;

  static File defaultProjectionFile() {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME is unavailable for catalog read projection');
    }
    return File(
      '$home/Library/Application Support/com.cnxdev.dextryx.images/$projectionFilename',
    );
  }

  Future<File> refresh() async {
    final workplaces = await _workplaceRepository.getAll();
    final activeId = await _workplaceRepository.getCurrentWorkplaceId();

    final assets = <AssetRecord>[];
    for (final workplace in workplaces) {
      assets.addAll(await _assetRepository.getByWorkplace(workplace.id));
    }
    assets.sort((a, b) {
      final imported = a.importedAt.compareTo(b.importedAt);
      if (imported != 0) return imported;
      return a.id.compareTo(b.id);
    });

    final buffer = StringBuffer()
      ..writeln(schemaHeader)
      ..writeln('ACTIVE\t${_escape(activeId ?? '')}');

    for (final workplace in workplaces) {
      buffer.writeln('WORKPLACE\t${_escape(workplace.id)}\t${_escape(workplace.name)}');
    }

    for (var index = 0; index < assets.length; index++) {
      final asset = assets[index];
      buffer.writeln([
        'ASSET',
        _escape(asset.id),
        _escape(asset.workplaceId),
        _escape(asset.sourcePath),
        _escape(asset.managedPath ?? ''),
        asset.storageMode.name,
        asset.missing ? '1' : '0',
        index.toString(),
      ].join('\t'));
    }

    await _projectionFile.parent.create(recursive: true);
    final temporary = File('${_projectionFile.path}.partial');
    await temporary.writeAsString(buffer.toString(), flush: true);
    if (await _projectionFile.exists()) {
      await _projectionFile.delete();
    }
    return temporary.rename(_projectionFile.path);
  }

  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll('\t', '\\t')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r');
}
