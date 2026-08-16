import 'package:hive/hive.dart';

import '../../domain/repositories/workplace_repository.dart';
import '../../domain/workplace.dart';

class HiveWorkplaceRepository implements WorkplaceRepository {
  HiveWorkplaceRepository({
    required Box<dynamic> workplacesBox,
    required Box<dynamic> settingsBox,
  })  : _workplacesBox = workplacesBox,
        _settingsBox = settingsBox;

  static const currentWorkplaceKey = 'currentWorkplaceId';

  final Box<dynamic> _workplacesBox;
  final Box<dynamic> _settingsBox;

  @override
  Future<List<Workplace>> getAll() async {
    final workplaces = _workplacesBox.values
        .whereType<Map>()
        .map(Workplace.fromMap)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return workplaces;
  }

  @override
  Future<Workplace?> getById(String id) async {
    final value = _workplacesBox.get(id);
    return value is Map ? Workplace.fromMap(value) : null;
  }

  @override
  Future<void> save(Workplace workplace) {
    return _workplacesBox.put(workplace.id, workplace.toMap());
  }

  @override
  Future<void> delete(String id) => _workplacesBox.delete(id);

  @override
  Future<String?> getCurrentWorkplaceId() async {
    return _settingsBox.get(currentWorkplaceKey) as String?;
  }

  @override
  Future<void> setCurrentWorkplaceId(String id) {
    return _settingsBox.put(currentWorkplaceKey, id);
  }
}
