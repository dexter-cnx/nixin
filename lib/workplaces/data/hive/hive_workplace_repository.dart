import '../../../storage/app_storage.dart';
import '../../domain/repositories/workplace_repository.dart';
import '../../domain/workplace.dart';

class HiveWorkplaceRepository implements WorkplaceRepository {
  HiveWorkplaceRepository({
    required KeyValueStore workplacesStore,
    required KeyValueStore settingsStore,
  })  : _workplacesStore = workplacesStore,
        _settingsStore = settingsStore;

  static const currentWorkplaceKey = 'currentWorkplaceId';

  final KeyValueStore _workplacesStore;
  final KeyValueStore _settingsStore;

  @override
  Future<List<Workplace>> getAll() async {
    final workplaces = _workplacesStore.values
        .whereType<Map>()
        .map(Workplace.fromMap)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return workplaces;
  }

  @override
  Future<Workplace?> getById(String id) async {
    final value = _workplacesStore.read(id);
    return value is Map ? Workplace.fromMap(value) : null;
  }

  @override
  Future<void> save(Workplace workplace) {
    return _workplacesStore.write(workplace.id, workplace.toMap());
  }

  @override
  Future<void> delete(String id) => _workplacesStore.delete(id);

  @override
  Future<String?> getCurrentWorkplaceId() async {
    return _settingsStore.read(currentWorkplaceKey) as String?;
  }

  @override
  Future<void> setCurrentWorkplaceId(String id) {
    return _settingsStore.write(currentWorkplaceKey, id);
  }
}
