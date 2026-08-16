import 'package:hive/hive.dart';

import '../../domain/asset_record.dart';
import '../../domain/repositories/asset_repository.dart';

class HiveAssetRepository implements AssetRepository {
  HiveAssetRepository(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async {
    final assets = _box.values
        .whereType<Map>()
        .map(AssetRecord.fromMap)
        .where((asset) => asset.workplaceId == workplaceId)
        .toList()
      ..sort((a, b) => a.importedAt.compareTo(b.importedAt));
    return assets;
  }

  @override
  Future<AssetRecord?> getById(String id) async {
    final value = _box.get(id);
    return value is Map ? AssetRecord.fromMap(value) : null;
  }

  @override
  Future<void> save(AssetRecord asset) => _box.put(asset.id, asset.toMap());

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    final keys = <dynamic>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is Map && value['workplaceId'] == workplaceId) {
        keys.add(key);
      }
    }
    if (keys.isNotEmpty) await _box.deleteAll(keys);
  }
}
