import 'package:hive/hive.dart';

import '../../../storage/app_storage.dart';
import '../../../storage/hive/hive_app_storage.dart';
import '../../domain/import_batch.dart';
import '../../domain/repositories/import_repository.dart';

class HiveImportRepository implements ImportRepository {
  HiveImportRepository(Object store) : _store = _asStore(store);

  final KeyValueStore _store;

  static KeyValueStore _asStore(Object store) {
    if (store is KeyValueStore) return store;
    if (store is Box<dynamic>) return HiveKeyValueStore(store);
    throw ArgumentError.value(store, 'store', 'Unsupported storage backend');
  }

  @override
  Future<List<ImportBatch>> getByWorkplace(String workplaceId) async {
    final batches = _store.values
        .whereType<Map>()
        .map(ImportBatch.fromMap)
        .where((batch) => batch.workplaceId == workplaceId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return batches;
  }

  @override
  Future<ImportBatch?> getById(String id) async {
    final value = _store.read(id);
    return value is Map ? ImportBatch.fromMap(value) : null;
  }

  @override
  Future<void> save(ImportBatch batch) =>
      _store.write(batch.id, batch.toMap());
}
