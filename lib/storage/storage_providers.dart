import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_storage.dart';

final appStorageProvider = Provider<AppStorage>((ref) {
  throw StateError(
    'appStorageProvider must be overridden at application bootstrap',
  );
});

final settingsStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(appStorageProvider).settings;
});

final workplacesStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(appStorageProvider).workplaces;
});

final assetsStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(appStorageProvider).assets;
});

final importBatchesStoreProvider = Provider<KeyValueStore>((ref) {
  return ref.watch(appStorageProvider).importBatches;
});
