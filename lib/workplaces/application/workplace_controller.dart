import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/hive/hive_asset_repository.dart';
import '../data/hive/hive_workplace_repository.dart';
import '../domain/repositories/asset_repository.dart';
import '../domain/repositories/workplace_repository.dart';
import '../domain/workplace.dart';

class WorkplaceState {
  const WorkplaceState({
    this.workplaces = const [],
    this.currentWorkplaceId,
    this.loading = true,
    this.errorMessage,
  });

  final List<Workplace> workplaces;
  final String? currentWorkplaceId;
  final bool loading;
  final String? errorMessage;

  Workplace? get currentWorkplace {
    final id = currentWorkplaceId;
    if (id == null) return null;
    for (final workplace in workplaces) {
      if (workplace.id == id) return workplace;
    }
    return null;
  }

  WorkplaceState copyWith({
    List<Workplace>? workplaces,
    String? currentWorkplaceId,
    bool clearCurrentWorkplace = false,
    bool? loading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return WorkplaceState(
      workplaces: workplaces ?? this.workplaces,
      currentWorkplaceId: clearCurrentWorkplace
          ? null
          : currentWorkplaceId ?? this.currentWorkplaceId,
      loading: loading ?? this.loading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final workplacesBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('workplaces');
});

final assetsBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('assets');
});

final workplaceSettingsBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('studio_settings');
});

final workplaceRepositoryProvider = Provider<WorkplaceRepository>((ref) {
  return HiveWorkplaceRepository(
    workplacesBox: ref.watch(workplacesBoxProvider),
    settingsBox: ref.watch(workplaceSettingsBoxProvider),
  );
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return HiveAssetRepository(ref.watch(assetsBoxProvider));
});

final workplaceControllerProvider =
    StateNotifierProvider<WorkplaceController, WorkplaceState>((ref) {
  return WorkplaceController(
    workplaceRepository: ref.watch(workplaceRepositoryProvider),
    assetRepository: ref.watch(assetRepositoryProvider),
  );
});

class WorkplaceController extends StateNotifier<WorkplaceState> {
  WorkplaceController({
    required WorkplaceRepository workplaceRepository,
    required AssetRepository assetRepository,
    DateTime Function()? now,
    String Function()? createId,
    bool initializeImmediately = true,
  })  : _workplaceRepository = workplaceRepository,
        _assetRepository = assetRepository,
        _now = now ?? DateTime.now,
        _createId = createId ?? _defaultId,
        super(const WorkplaceState()) {
    if (initializeImmediately) unawaited(initialize());
  }

  static const defaultWorkplaceName = 'My workplace';

  final WorkplaceRepository _workplaceRepository;
  final AssetRepository _assetRepository;
  final DateTime Function() _now;
  final String Function() _createId;

  static String _defaultId() =>
      'workplace-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> initialize() async {
    try {
      var workplaces = await _workplaceRepository.getAll();
      if (workplaces.isEmpty) {
        final now = _now();
        final initial = Workplace(
          id: _createId(),
          name: defaultWorkplaceName,
          createdAt: now,
          updatedAt: now,
          isDefault: true,
        );
        await _workplaceRepository.save(initial);
        workplaces = [initial];
      }

      var currentId = await _workplaceRepository.getCurrentWorkplaceId();
      if (!workplaces.any((workplace) => workplace.id == currentId)) {
        currentId = workplaces.first.id;
        await _workplaceRepository.setCurrentWorkplaceId(currentId);
      }

      state = WorkplaceState(
        workplaces: workplaces,
        currentWorkplaceId: currentId,
        loading: false,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        errorMessage: '$error',
      );
    }
  }

  Future<Workplace> createWorkplace(String name) async {
    final normalized = _normalizeName(name);
    final now = _now();
    final workplace = Workplace(
      id: _createId(),
      name: normalized,
      createdAt: now,
      updatedAt: now,
    );
    await _workplaceRepository.save(workplace);
    final workplaces = [...state.workplaces, workplace];
    state = state.copyWith(workplaces: workplaces, clearError: true);
    return workplace;
  }

  Future<void> switchWorkplace(String id) async {
    if (!state.workplaces.any((workplace) => workplace.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown workplace');
    }
    await _workplaceRepository.setCurrentWorkplaceId(id);
    state = state.copyWith(currentWorkplaceId: id, clearError: true);
  }

  Future<void> renameWorkplace(String id, String name) async {
    final normalized = _normalizeName(name);
    final index = state.workplaces.indexWhere((workplace) => workplace.id == id);
    if (index < 0) throw ArgumentError.value(id, 'id', 'Unknown workplace');

    final updated = state.workplaces[index].copyWith(
      name: normalized,
      updatedAt: _now(),
    );
    await _workplaceRepository.save(updated);
    final workplaces = [...state.workplaces]..[index] = updated;
    state = state.copyWith(workplaces: workplaces, clearError: true);
  }

  Future<void> deleteWorkplace(String id) async {
    if (state.workplaces.length <= 1) {
      throw StateError('At least one Workplace must remain');
    }
    if (!state.workplaces.any((workplace) => workplace.id == id)) {
      throw ArgumentError.value(id, 'id', 'Unknown workplace');
    }

    await _assetRepository.deleteByWorkplace(id);
    await _workplaceRepository.delete(id);

    final workplaces = state.workplaces
        .where((workplace) => workplace.id != id)
        .toList(growable: false);
    var currentId = state.currentWorkplaceId;
    if (currentId == id ||
        !workplaces.any((workplace) => workplace.id == currentId)) {
      currentId = workplaces.first.id;
      await _workplaceRepository.setCurrentWorkplaceId(currentId);
    }

    state = state.copyWith(
      workplaces: workplaces,
      currentWorkplaceId: currentId,
      clearError: true,
    );
  }

  String _normalizeName(String value) {
    final name = value.trim();
    if (name.isEmpty) throw ArgumentError.value(value, 'name', 'Name is empty');
    return name;
  }
}
