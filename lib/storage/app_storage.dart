abstract interface class KeyValueStore {
  Iterable<dynamic> get keys;
  Iterable<dynamic> get values;
  String? get path;

  Object? read(Object key, {Object? defaultValue});
  Future<void> write(Object key, Object? value);
  Future<void> delete(Object key);
  Future<void> deleteAll(Iterable<Object> keys);
}

abstract interface class AppStorage {
  KeyValueStore get settings;
  KeyValueStore get workplaces;
  KeyValueStore get assets;
  KeyValueStore get importBatches;
}
