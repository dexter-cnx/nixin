import '../import_batch.dart';

abstract interface class ImportRepository {
  Future<List<ImportBatch>> getByWorkplace(String workplaceId);
  Future<ImportBatch?> getById(String id);
  Future<void> save(ImportBatch batch);
}
