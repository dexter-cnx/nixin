import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_browser_controller.dart';
import 'import_controller.dart';
import 'import_state.dart';
import 'workplace_controller.dart';

/// Keeps the disposable native read projection synchronized with authoritative
/// repository changes. The projection is never read back into Flutter.
final catalogReadProjectionSyncProvider = Provider<void>((ref) {
  final writer = ref.watch(catalogReadProjectionWriterProvider);

  void refresh() => unawaited(writer.refresh());

  ref.listen<WorkplaceState>(
    workplaceControllerProvider,
    (previous, next) {
      if (next.loading) return;
      if (previous?.workplaces != next.workplaces ||
          previous?.currentWorkplaceId != next.currentWorkplaceId) {
        refresh();
      }
    },
    fireImmediately: true,
  );

  ref.listen<ImportState>(
    importControllerProvider,
    (previous, next) {
      final wasBusy = previous?.busy ?? false;
      if (wasBusy && !next.busy) refresh();
    },
  );

  ref.listen<AssetBrowserState>(
    assetBrowserControllerProvider,
    (previous, next) {
      if (next.loading) return;
      if (!identical(previous?.assets, next.assets)) refresh();
    },
  );
});
