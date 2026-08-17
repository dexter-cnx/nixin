import 'asset_record.dart';

abstract interface class ImportPreferences {
  AssetStorageMode readStorageMode();
  String? readManagedDestination();
  Future<void> writeStorageMode(AssetStorageMode mode);
  Future<void> writeManagedDestination(String path);
}
