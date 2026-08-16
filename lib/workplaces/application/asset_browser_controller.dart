import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/asset_record.dart';
import '../domain/repositories/asset_repository.dart';
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
    this.errorMessage,
  });

  final String? workplaceId;
  final List<AssetRecord> assets;
  final String? selectedAssetId;
  final AssetSortOrder sortOrder;
  final bool loading;
  final String? errorMessage;

  AssetRecord? get selectedAsset {
    final id = selectedAssetId;
    if (id == null) return null;
    for (final asset in assets) {
      if (asset.id == id) return asset;
    }
    return null;
  }

  AssetBrowserState copyWith({
    String? workplaceId,
    bool clearWorkplaceId = false,
    List<AssetRecord>? assets,
    String? selectedAssetId,
    bool clearSelection = false,
    AssetSortOrder? sortOrder,
    bool? loading,
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
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

final assetBrowserControllerProvider =
    StateNotifierProvider<AssetBrowserController, AssetBrowserState>((ref) {
  final controller = AssetBrowserController(
    assetRepository: ref.watch(assetRepositoryProvider),
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
  AssetBrowserController({required AssetRepository assetRepository})
      : _assetRepository = assetRepository,
        super(const AssetBrowserState());

  final AssetRepository _assetRepository;
  int _loadRevision = 0;

  Future<void> load(String? workplaceId) async {
    final revision = ++_loadRevision;
    if (workplaceId == null) {
      state = const AssetBrowserState(loading: false);
      return;
    }

    state = state.copyWith(
      workplaceId: workplaceId,
      loading: true,
      clearError: true,
      clearSelection: state.workplaceId != workplaceId,
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
    } catch (error) {
      if (revision != _loadRevision) return;
      state = state.copyWith(
        loading: false,
        errorMessage: '$error',
      );
    }
  }

  Future<void> refresh() => load(state.workplaceId);

  void select(String assetId) {
    if (!state.assets.any((asset) => asset.id == assetId)) return;
    state = state.copyWith(selectedAssetId: assetId, clearError: true);
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
