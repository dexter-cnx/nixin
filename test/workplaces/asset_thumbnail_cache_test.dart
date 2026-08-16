import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/workplaces/application/asset_thumbnail_cache.dart';
import 'package:nixin_studio_v8/workplaces/domain/asset_record.dart';

void main() {
  late Directory tempDir;
  late Directory cacheDir;
  late File source;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nixin-thumb-cache-');
    cacheDir = Directory('${tempDir.path}/cache');
    source = File('${tempDir.path}/source.jpg');
    await source.writeAsBytes([1, 2, 3, 4]);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('deduplicates concurrent generation for the same asset version', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async {
        encodes++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _jpeg(encodes);
      },
    );
    final asset = _asset(source.path);

    final results = await Future.wait([
      cache.thumbnail(asset),
      cache.thumbnail(asset),
      cache.thumbnail(asset),
    ]);

    expect(encodes, 1);
    expect(results.whereType<Uint8List>(), hasLength(3));
  });

  test('bounds generation across distinct assets', () async {
    var active = 0;
    var maxActive = 0;
    final files = <File>[];
    for (var index = 0; index < 6; index++) {
      final file = File('${tempDir.path}/source-$index.jpg');
      await file.writeAsBytes([index, 1, 2, 3]);
      files.add(file);
    }
    final cache = _cache(
      cacheDir,
      maxConcurrentGenerations: 2,
      encoder: (bytes, size) async {
        active++;
        if (active > maxActive) maxActive = active;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        active--;
        return _jpeg(bytes.first);
      },
    );

    await Future.wait([
      for (var index = 0; index < files.length; index++)
        cache.thumbnail(_asset(files[index].path, id: 'asset-$index')),
    ]);

    expect(maxActive, lessThanOrEqualTo(2));
  });

  test('modified timestamp invalidates the prior cached version', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async => _jpeg(++encodes),
    );
    final first = _asset(source.path, modifiedAt: DateTime.utc(2026, 8, 16, 1));
    final second = _asset(source.path, modifiedAt: DateTime.utc(2026, 8, 16, 2));

    await cache.thumbnail(first);
    await cache.thumbnail(second);

    expect(encodes, 2);
    final files = await cacheDir.list().where((entry) => entry is File).toList();
    expect(files.where((entry) => !entry.path.endsWith('.partial')), hasLength(1));
  });

  test('source filesystem metadata invalidates an existing cached version', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async => _jpeg(++encodes),
    );
    final asset = _asset(source.path);

    await cache.thumbnail(asset);
    await source.writeAsBytes([9, 8, 7, 6, 5]);
    await source.setLastModified(DateTime.utc(2026, 8, 16, 12));
    await cache.thumbnail(asset);

    expect(encodes, 2);
  });

  test('corrupt cached jpeg is deleted and regenerated', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async => _jpeg(++encodes),
      validator: (bytes) async => bytes.length == 5 && bytes[0] == 0xff,
    );
    final asset = _asset(source.path);
    await cache.thumbnail(asset);
    final cached = (await cacheDir.list().where((entry) => entry is File).toList())
        .cast<File>()
        .single;
    await cached.writeAsBytes([0xff, 0xd8, 0, 0, 0xff, 0xd9]);

    final regenerated = await cache.thumbnail(asset);

    expect(encodes, 2);
    expect(regenerated, isNotNull);
    expect(await cached.readAsBytes(), _jpeg(2));
  });

  test('raw assets do not invoke raster thumbnail decoding', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async {
        encodes++;
        return _jpeg(encodes);
      },
    );
    final raw = _asset(source.path, mediaType: AssetMediaType.raw);

    expect(await cache.thumbnail(raw), isNull);
    expect(encodes, 0);
  });

  test('missing assets do not read or generate from unavailable originals', () async {
    var encodes = 0;
    final cache = _cache(
      cacheDir,
      encoder: (bytes, size) async {
        encodes++;
        return _jpeg(encodes);
      },
    );
    final missing = _asset(source.path, missing: true);

    expect(await cache.thumbnail(missing), isNull);
    expect(encodes, 0);
  });

  test('prune enforces entry count without failing catalog use', () async {
    await cacheDir.create(recursive: true);
    for (var index = 0; index < 5; index++) {
      final file = File('${cacheDir.path}/$index.jpg');
      await file.writeAsBytes(_jpeg(index));
      await file.setLastModified(DateTime.utc(2026, 8, 16, 0, index));
    }
    final cache = _cache(
      cacheDir,
      maxEntries: 2,
      maxBytes: 1024,
      encoder: (bytes, size) async => _jpeg(99),
    );

    await cache.prune();

    final files = await cacheDir.list().where((entry) => entry is File).toList();
    expect(files, hasLength(2));
  });
}

AssetThumbnailCache _cache(
  Directory root, {
  int maxEntries = 2048,
  int maxBytes = 512 * 1024 * 1024,
  int maxConcurrentGenerations = 2,
  required ThumbnailEncoder encoder,
  ThumbnailValidator? validator,
}) {
  return AssetThumbnailCache(
    root: root,
    maxEntries: maxEntries,
    maxBytes: maxBytes,
    maxConcurrentGenerations: maxConcurrentGenerations,
    encoder: encoder,
    validator: validator ?? (bytes) async => true,
  );
}

AssetRecord _asset(
  String path, {
  String id = 'asset-1',
  DateTime? modifiedAt,
  AssetMediaType mediaType = AssetMediaType.raster,
  bool missing = false,
}) {
  return AssetRecord(
    id: id,
    workplaceId: 'workplace-1',
    originalFilename: 'source.jpg',
    sourcePath: path,
    storageMode: AssetStorageMode.linked,
    mediaType: mediaType,
    format: mediaType == AssetMediaType.raw ? 'nef' : 'jpg',
    fileSize: 4,
    importedAt: DateTime.utc(2026, 8, 16),
    modifiedAt: modifiedAt ?? DateTime.utc(2026, 8, 16),
    missing: missing,
  );
}

Uint8List _jpeg(int marker) => Uint8List.fromList([0xff, 0xd8, marker, 0xff, 0xd9]);
