import '../../../storage/app_storage.dart';
import '../../domain/import_batch.dart';
import '../../domain/repositories/import_repository.dart';

class HiveImportRepository implements ImportRepository {
  HiveImportRepository(this._store);

  final KeyValueStore _store;

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
