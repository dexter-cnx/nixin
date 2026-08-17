import 'package:hive/hive.dart';

import '../../../storage/app_storage.dart';
import '../../../storage/hive/hive_app_storage.dart';
import '../../domain/asset_record.dart';
import '../../domain/repositories/asset_repository.dart';

class HiveAssetRepository implements AssetRepository {
  HiveAssetRepository(Object store) : _store = _asStore(store);

  final KeyValueStore _store;

  static KeyValueStore _asStore(Object store) {
    if (store is KeyValueStore) return store;
    if (store is Box<dynamic>) return HiveKeyValueStore(store);
    throw ArgumentError.value(store, 'store', 'Unsupported storage backend');
  }

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
  Future<void> save(AssetRecord asset) => _store.write(asset.id, asset.toMap());

  @override
  Future<void> delete(String id) => _store.delete(id);

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    final keys = <Object>[];
    for (final key in _store.keys) {
      if (key == null) continue;
      final value = _store.read(key as Object);
      if (value is Map && value['workplaceId'] == workplaceId) {
        keys.add(key);
      }
    }
    if (keys.isNotEmpty) await _store.deleteAll(keys);
  }
}
