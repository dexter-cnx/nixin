import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/catalog_read_projection_writer.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/asset_repository.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/workplace_repository.dart';
import 'package:nixin_studio_v8/workplaces/domain/workplace.dart';

void main() {
  test('Hive-authority semantics serialize to shared Rust parity fixture', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'dextryx-catalog-parity-',
    );
    addTearDown(() => tempDirectory.delete(recursive: true));

    final writer = CatalogReadProjectionWriter(
      workplaceRepository: _WorkplaceFixtureRepository(),
      assetRepository: _AssetFixtureRepository(),
      projectionFile: File('${tempDirectory.path}/projection.tsv'),
    );

    final output = await writer.refresh();
    final expected = await File(
      'test/fixtures/catalog_authority_parity_v1.tsv',
    ).readAsString();

    expect(await output.readAsString(), expected);
  });
}

final class _WorkplaceFixtureRepository implements WorkplaceRepository {
  static final workplaces = <Workplace>[
    Workplace(
      id: 'workplace-my',
      name: 'My workplace',
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      isDefault: true,
    ),
    Workplace(
      id: 'workplace-travel',
      name: 'Travel\t2026',
      createdAt: DateTime.utc(2026, 1, 2),
      updatedAt: DateTime.utc(2026, 1, 2),
    ),
  ];

  @override
  Future<List<Workplace>> getAll() async => workplaces;

  @override
  Future<Workplace?> getById(String id) async => _firstWhereOrNull(
        workplaces,
        (workplace) => workplace.id == id,
      );

  @override
  Future<String?> getCurrentWorkplaceId() async => 'workplace-travel';

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> save(Workplace workplace) async {}

  @override
  Future<void> setCurrentWorkplaceId(String id) async {}
}

final class _AssetFixtureRepository implements AssetRepository {
  static final assets = <AssetRecord>[
    AssetRecord(
      id: 'asset-linked-b',
      workplaceId: 'workplace-travel',
      originalFilename: 'b.jpg',
      sourcePath: '/external/b.jpg',
      storageMode: AssetStorageMode.linked,
      mediaType: AssetMediaType.raster,
      format: 'jpg',
      fileSize: 20,
      importedAt: DateTime.utc(2026, 1, 3, 12),
      modifiedAt: DateTime.utc(2026, 1, 3, 12),
      missing: true,
    ),
    AssetRecord(
      id: 'asset-managed',
      workplaceId: 'workplace-my',
      originalFilename: 'managed.nef',
      sourcePath: '/external/managed.nef',
      managedPath: '/managed/library/managed.nef',
      storageMode: AssetStorageMode.managed,
      mediaType: AssetMediaType.raw,
      format: 'nef',
      fileSize: 100,
      importedAt: DateTime.utc(2026, 1, 1, 12),
      modifiedAt: DateTime.utc(2026, 1, 1, 12),
    ),
    AssetRecord(
      id: 'asset-linked-a',
      workplaceId: 'workplace-travel',
      originalFilename: 'a.jpg',
      sourcePath: '/external/a.jpg',
      storageMode: AssetStorageMode.linked,
      mediaType: AssetMediaType.raster,
      format: 'jpg',
      fileSize: 10,
      importedAt: DateTime.utc(2026, 1, 3, 12),
      modifiedAt: DateTime.utc(2026, 1, 3, 12),
    ),
  ];

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async => assets
      .where((asset) => asset.workplaceId == workplaceId)
      .toList(growable: false);

  @override
  Future<AssetRecord?> getById(String id) async => _firstWhereOrNull(
        assets,
        (asset) => asset.id == id,
      );

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {}

  @override
  Future<void> save(AssetRecord asset) async {}
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
