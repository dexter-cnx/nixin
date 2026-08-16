import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../domain/asset_record.dart';
import '../domain/repositories/asset_repository.dart';
import 'asset_availability_service.dart';
import 'import_controller.dart';
import 'import_state.dart';
import 'workplace_controller.dart';

enum AssetSortOrder { importedAscending, importedDescending, nameAscending }

class AssetBrowserState {
  const AssetBrowserState({
    this.workplaceId,
    this.assets = const [],
    this.selectedAssetId,
    this.sortOrder = AssetSortOrder.importedAscending,
    this.loading = true,
    this.scanningAvailability = false,
    this.errorMessage,
  });

  final String? workplaceId;
  final List<AssetRecord> assets;
  final String? selectedAssetId;
  final AssetSortOrder sortOrder;
  final bool loading;
  final bool scanningAvailability;
  final String? errorMessage;

  AssetRecord? get selectedAsset {
    final id = selectedAssetId;
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  int get missingCount => assets.where((asset) => asset.missing).length;

  AssetBrowserState copyWith({
    String? workplaceId,
    bool clearWorkplaceId = false,
    List<AssetRecord>? assets,
    String? selectedAssetId,
    bool clearSelection = false,
    AssetSortOrder? sortOrder,
    bool? loading,
    bool? scanningAvailability,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AssetBrowserState(
      workplaceId: clearWorkplaceId ? null : workplaceId ?? this.workplaceId,
      assets: assets ?? this.assets,
      selectedAssetId:
          clearSelection ? null : selectedAssetId ?? this.selectedAssetId,
      sortOrder: sortOrder ?? this.sortOrder,
      loading: loading ?? this.loading,
      scanningAvailability:
          scanningAvailability ?? this.scanningAvailability,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final assetBrowserControllerProvider =
    StateNotifierProvider<AssetBrowserController, AssetBrowserState>((ref) {
  final controller = AssetBrowserController(
    assetRepository: ref.watch(assetRepositoryProvider),
    availabilityService: ref.watch(assetAvailabilityServiceProvider),
  );

  ref.listen<String?>(
    workplaceControllerProvider.select((state) => state.currentWorkplaceId),
    (_, next) => unawaited(controller.load(next)),
    fireImmediately: true,
  );

  ref.listen<ImportPhase>(
    importControllerProvider.select((state) => state.phase),
    (previous, next) {
      if (next == ImportPhase.completed || next == ImportPhase.cancelled) {
        unawaited(controller.refresh());
      }
    },
  );

  return controller;
});

class AssetBrowserController extends StateNotifier<AssetBrowserState> {
  AssetBrowserController({
    required AssetRepository assetRepository,
    required AssetAvailabilityService availabilityService,
    bool autoScanAvailability = true,
  })  : _assetRepository = assetRepository,
        _availabilityService = availabilityService,
        _autoScanAvailability = autoScanAvailability,
        super(const AssetBrowserState());

  final AssetRepository _assetRepository;
  final AssetAvailabilityService _availabilityService;
  final bool _autoScanAvailability;
  int _loadRevision = 0;
  int _availabilityRevision = 0;

  Future<void> load(String? workplaceId) async {
    final revision = ++_loadRevision;
    ++_availabilityRevision;
    if (workplaceId == null) {
      state = const AssetBrowserState(loading: false);
      return;
    }

    final workplaceChanged = state.workplaceId != workplaceId;
    state = state.copyWith(
      workplaceId: workplaceId,
      assets: workplaceChanged ? const [] : state.assets,
      loading: true,
      scanningAvailability: false,
      clearError: true,
      clearSelection: workplaceChanged,
    );

    try {
      final assets = await _assetRepository.getByWorkplace(workplaceId);
      if (revision != _loadRevision) return;
      final sorted = _sort(assets, state.sortOrder);
      final selected = sorted.any((asset) => asset.id == state.selectedAssetId)
          ? state.selectedAssetId
          : null;
      state = AssetBrowserState(
        workplaceId: workplaceId,
        assets: sorted,
        selectedAssetId: selected,
        sortOrder: state.sortOrder,
        loading: false,
      );
      if (_autoScanAvailability) unawaited(scanAvailability());
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        assets: const [],
        clearSelection: true,
        loading: false,
        scanningAvailability: false,
        errorMessage: '$error',
      );
    }
  }

  Future<void> refresh() => load(state.workplaceId);

  Future<void> scanAvailability() async {
    if (state.loading || state.assets.isEmpty) return;
    final revision = ++_availabilityRevision;
    final snapshot = state.assets;
    state = state.copyWith(scanningAvailability: true);
    try {
      final missingById = await _availabilityService.missingById(snapshot);
      if (revision != _availabilityRevision) return;
      final updated = <AssetRecord>[];
      for (final asset in snapshot) {
        if (revision != _availabilityRevision) return;
        final currentIndex = state.assets.indexWhere((item) => item.id == asset.id);
        if (currentIndex < 0) continue;
        final current = state.assets[currentIndex];
        if (current.effectivePath != asset.effectivePath) continue;

        final missing = missingById[asset.id] ?? current.missing;
        final next = missing == current.missing
            ? current
            : current.copyWith(missing: missing);
        updated.add(next);
        if (!identical(next, current)) {
          await _assetRepository.save(next);
          if (revision != _availabilityRevision) return;
        }
      }
      if (revision != _availabilityRevision) return;

      final currentById = {for (final asset in state.assets) asset.id: asset};
      for (final asset in updated) {
        final current = currentById[asset.id];
        if (current != null && current.effectivePath == asset.effectivePath) {
          currentById[asset.id] = asset;
        }
      }
      state = state.copyWith(
        assets: _sort(currentById.values, state.sortOrder),
        scanningAvailability: false,
      );
    } catch (_) {
      if (revision != _availabilityRevision) return;
      state = state.copyWith(scanningAvailability: false);
    }
  }

  void select(String assetId) {
    if (!state.assets.any((asset) => asset.id == assetId)) return;
    state = state.copyWith(selectedAssetId: assetId, clearError: true);
  }

  bool selectByEffectivePath(String path) {
    for (final asset in state.assets) {
      if (asset.effectivePath == path) {
        select(asset.id);
        return true;
      }
    }
    return false;
  }

  Future<bool> relinkAsset(String assetId, String replacementPath) async {
    ++_availabilityRevision;
    state = state.copyWith(scanningAvailability: false);

    final index = state.assets.indexWhere((asset) => asset.id == assetId);
    if (index < 0) return false;
    final current = state.assets[index];
    final candidate = current.storageMode == AssetStorageMode.managed
        ? current.copyWith(managedPath: replacementPath)
        : current.copyWith(sourcePath: replacementPath);
    final exists =
        (await _availabilityService.missingById([candidate]))[current.id] ==
            false;
    if (!exists) return false;

    final updated = candidate.copyWith(missing: false);
    await _assetRepository.save(updated);
    final assets = [...state.assets]..[index] = updated;
    state = state.copyWith(assets: assets, clearError: true);
    return true;
  }

  Future<int> relinkMissingFromFolder(String root) async {
    final index = await _availabilityService.filesByLowercaseFilename(root);
    var relinked = 0;
    for (final asset in state.assets.where((asset) => asset.missing).toList()) {
      final recoveryFilename = asset.storageMode == AssetStorageMode.managed &&
              asset.managedPath != null
          ? p.basename(asset.managedPath!).toLowerCase()
          : asset.originalFilename.toLowerCase();
      final matches = index[recoveryFilename];
      if (matches != null &&
          matches.length == 1 &&
          await relinkAsset(asset.id, matches.single)) {
        relinked++;
      }
      await Future<void>.delayed(Duration.zero);
    }
    return relinked;
  }

  Future<void> removeFromWorkplace(String assetId) async {
    ++_availabilityRevision;
    state = state.copyWith(scanningAvailability: false);

    await _assetRepository.delete(assetId);
    final assets = state.assets.where((asset) => asset.id != assetId).toList();
    state = state.copyWith(
      assets: assets,
      clearSelection: state.selectedAssetId == assetId,
      clearError: true,
    );
  }

  void setSortOrder(AssetSortOrder order) {
    state = state.copyWith(
      sortOrder: order,
      assets: _sort(state.assets, order),
    );
  }

  static List<AssetRecord> _sort(
    Iterable<AssetRecord> assets,
    AssetSortOrder order,
  ) {
    final sorted = assets.toList(growable: false);
    switch (order) {
      case AssetSortOrder.importedAscending:
        sorted.sort((a, b) => a.importedAt.compareTo(b.importedAt));
        break;
      case AssetSortOrder.importedDescending:
        sorted.sort((a, b) => b.importedAt.compareTo(a.importedAt));
        break;
      case AssetSortOrder.nameAscending:
        sorted.sort(
          (a, b) => a.originalFilename
              .toLowerCase()
              .compareTo(b.originalFilename.toLowerCase()),
        );
        break;
    }
    return sorted;
  }
}
