import '../../../storage/app_storage.dart';
import '../../domain/asset_record.dart';
import '../../domain/import_preferences.dart';

class HiveImportPreferences implements ImportPreferences {
  HiveImportPreferences(this._store);

  final KeyValueStore _store;

  @override
  AssetStorageMode readStorageMode() {
    final value = _store.read(
      'importStorageMode',
      defaultValue: 'linked',
    ) as String;
    return AssetStorageMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => AssetStorageMode.linked,
    );
  }

  @override
  String? readManagedDestination() =>
      _store.read('managedImportDestination') as String?;

  @override
  Future<void> writeStorageMode(AssetStorageMode mode) =>
      _store.write('importStorageMode', mode.name);

  @override
  Future<void> writeManagedDestination(String path) =>
      _store.write('managedImportDestination', path);
}
