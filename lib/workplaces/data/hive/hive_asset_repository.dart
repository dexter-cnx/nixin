import '../../../storage/app_storage.dart';
import '../../domain/asset_record.dart';
import '../../domain/repositories/asset_repository.dart';

class HiveAssetRepository implements AssetRepository {
  HiveAssetRepository(this._store);

  final KeyValueStore _store;

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async {
    final assets = _store.values
        .whereType<Map>()
        .map(AssetRecord.fromMap)
        .where((asset) => asset.workplaceId == workplaceId)
        .toList()
      ..sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return assets;
  }

  @override
  Future<AssetRecord?> getById(String id) async {
    final value = _store.read(id);
    return value is Map ? AssetRecord.fromMap(value) : null;
  }

  @override
  Future<void> save(AssetRecord asset) =>
      _store.write(asset.id, asset.toMap());

  @override
  Future<void> delete(String id) => _store.delete(id);

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    final keys = <Object>[];
    for (final key in _store.keys) {
      final value = _store.read(key as Object);
      if (value is Map && value['workplaceId'] == workplaceId) {
        keys.add(key as Object);
      }
    }
    if (keys.isNotEmpty) await _store.deleteAll(keys);
  }
}
