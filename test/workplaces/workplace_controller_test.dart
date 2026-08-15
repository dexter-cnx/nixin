import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/workplace_controller.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/asset_repository.dart';
import 'package:nixin_studio_v8/workplaces/domain/repositories/workplace_repository.dart';
import 'package:nixin_studio_v8/workplaces/domain/workplace.dart';

void main() {
  test('fresh catalog creates My workplace and persists it as current', () async {
    final workplaces = _MemoryWorkplaceRepository();
    final assets = _MemoryAssetRepository();
    final controller = WorkplaceController(
      workplaceRepository: workplaces,
      assetRepository: assets,
      now: () => DateTime.utc(2026, 8, 14),
      createId: () => 'w1',
      initializeImmediately: false,
    );

    await controller.initialize();

    expect(controller.state.workplaces, hasLength(1));
    expect(controller.state.currentWorkplace?.name, 'My workplace');
    expect(controller.state.currentWorkplace?.isDefault, isTrue);
    expect(workplaces.currentId, 'w1');
  });

  test('restores persisted current workplace', () async {
    final first = _workplace('w1', 'One');
    final second = _workplace('w2', 'Two');
    final workplaces = _MemoryWorkplaceRepository(
      values: [first, second],
      currentId: 'w2',
    );
    final controller = WorkplaceController(
      workplaceRepository: workplaces,
      assetRepository: _MemoryAssetRepository(),
      initializeImmediately: false,
    );

    await controller.initialize();

    expect(controller.state.currentWorkplaceId, 'w2');
    expect(controller.state.currentWorkplace?.name, 'Two');
  });

  test('create, switch and rename update catalog state', () async {
    var id = 0;
    final controller = WorkplaceController(
      workplaceRepository: _MemoryWorkplaceRepository(),
      assetRepository: _MemoryAssetRepository(),
      createId: () => 'w${++id}',
      now: () => DateTime.utc(2026, 8, 14),
      initializeImmediately: false,
    );
    await controller.initialize();

    final created = await controller.createWorkplace('  Wedding  ');
    await controller.switchWorkplace(created.id);
    await controller.renameWorkplace(created.id, 'Wedding 2026');

    expect(controller.state.currentWorkplace?.name, 'Wedding 2026');
    expect(controller.state.workplaces, hasLength(2));
  });

  test('cannot delete the last workplace', () async {
    final controller = WorkplaceController(
      workplaceRepository: _MemoryWorkplaceRepository(),
      assetRepository: _MemoryAssetRepository(),
      createId: () => 'w1',
      initializeImmediately: false,
    );
    await controller.initialize();

    await expectLater(
      controller.deleteWorkplace('w1'),
      throwsA(isA<StateError>()),
    );
  });

  test('deleting current workplace selects another and removes catalog assets', () async {
    final workplaces = _MemoryWorkplaceRepository(
      values: [_workplace('w1', 'One'), _workplace('w2', 'Two')],
      currentId: 'w2',
    );
    final assets = _MemoryAssetRepository();
    final controller = WorkplaceController(
      workplaceRepository: workplaces,
      assetRepository: assets,
      initializeImmediately: false,
    );
    await controller.initialize();

    await controller.deleteWorkplace('w2');

    expect(controller.state.currentWorkplaceId, 'w1');
    expect(assets.deletedWorkplaceIds, ['w2']);
  });
}

Workplace _workplace(String id, String name) {
  final date = DateTime.utc(2026, 8, 14);
  return Workplace(id: id, name: name, createdAt: date, updatedAt: date);
}

class _MemoryWorkplaceRepository implements WorkplaceRepository {
  _MemoryWorkplaceRepository({List<Workplace>? values, this.currentId})
      : values = {for (final value in values ?? const <Workplace>[]) value.id: value};

  final Map<String, Workplace> values;
  String? currentId;

  @override
  Future<void> delete(String id) async => values.remove(id);

  @override
  Future<List<Workplace>> getAll() async => values.values.toList();

  @override
  Future<Workplace?> getById(String id) async => values[id];

  @override
  Future<String?> getCurrentWorkplaceId() async => currentId;

  @override
  Future<void> save(Workplace workplace) async => values[workplace.id] = workplace;

  @override
  Future<void> setCurrentWorkplaceId(String id) async => currentId = id;
}

class _MemoryAssetRepository implements AssetRepository {
  final List<String> deletedWorkplaceIds = [];

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> deleteByWorkplace(String workplaceId) async {
    deletedWorkplaceIds.add(workplaceId);
  }

  @override
  Future<List<AssetRecord>> getByWorkplace(String workplaceId) async => const [];

  @override
  Future<AssetRecord?> getById(String id) async => null;

  @override
  Future<void> save(AssetRecord asset) async {}
}
