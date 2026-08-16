import '../asset_record.dart';

abstract interface class AssetRepository {
  Future<List<AssetRecord>> getByWorkplace(String workplaceId);
  Future<AssetRecord?> getById(String id);
  Future<void> save(AssetRecord asset);
  Future<void> delete(String id);
  Future<void> deleteByWorkplace(String workplaceId);
}
