import '../workplace.dart';

abstract interface class WorkplaceRepository {
  Future<List<Workplace>> getAll();
  Future<Workplace?> getById(String id);
  Future<void> save(Workplace workplace);
  Future<void> delete(String id);
  Future<String?> getCurrentWorkplaceId();
  Future<void> setCurrentWorkplaceId(String id);
}
