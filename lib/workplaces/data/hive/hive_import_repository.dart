import 'package:hive/hive.dart';

import '../../domain/import_batch.dart';
import '../../domain/repositories/import_repository.dart';

class HiveImportRepository implements ImportRepository {
  HiveImportRepository(this._box);

  final Box<dynamic> _box;

  @override
  Future<List<ImportBatch>> getByWorkplace(String workplaceId) async {
    final batches = _box.values
        .whereType<Map>()
        .map(ImportBatch.fromMap)
        .where((batch) => batch.workplaceId == workplaceId)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return batches;
  }

  @override
  Future<ImportBatch?> getById(String id) async {
    final value = _box.get(id);
    return value is Map ? ImportBatch.fromMap(value) : null;
  }

  @override
  Future<void> save(ImportBatch batch) => _box.put(batch.id, batch.toMap());
}
