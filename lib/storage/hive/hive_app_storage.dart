import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../app_storage.dart';

class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore(this._box);

  final Box<dynamic> _box;

  @override
  Iterable<dynamic> get keys => _box.keys;

  @override
  Iterable<dynamic> get values => _box.values;

  @override
  String? get path => _box.path;

  @override
  Object? read(Object key, {Object? defaultValue}) =>
      _box.get(key, defaultValue: defaultValue);

  @override
  Future<void> write(Object key, Object? value) => _box.put(key, value);

  @override
  Future<void> delete(Object key) => _box.delete(key);

  @override
  Future<void> deleteAll(Iterable<Object> keys) => _box.deleteAll(keys);
}

class HiveAppStorage implements AppStorage {
  HiveAppStorage._({
    required Box<dynamic> settingsBox,
    required Box<dynamic> workplacesBox,
    required Box<dynamic> assetsBox,
    required Box<dynamic> importBatchesBox,
  })  : settings = HiveKeyValueStore(settingsBox),
        workplaces = HiveKeyValueStore(workplacesBox),
        assets = HiveKeyValueStore(assetsBox),
        importBatches = HiveKeyValueStore(importBatchesBox);

  static Future<HiveAppStorage> open() async {
    await Hive.initFlutter();
    final boxes = await Future.wait<Box<dynamic>>([
      Hive.openBox<dynamic>('studio_settings'),
      Hive.openBox<dynamic>('workplaces'),
      Hive.openBox<dynamic>('assets'),
      Hive.openBox<dynamic>('import_batches'),
    ]);
    return HiveAppStorage._(
      settingsBox: boxes[0],
      workplacesBox: boxes[1],
      assetsBox: boxes[2],
      importBatchesBox: boxes[3],
    );
  }

  @override
  final KeyValueStore settings;

  @override
  final KeyValueStore workplaces;

  @override
  final KeyValueStore assets;

  @override
  final KeyValueStore importBatches;
}
