import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

import 'engine_image.dart';

abstract interface class StudioEngine {
  bool checkEngine();
  String version();
  String lastError();
  EngineImage? develop(String path);
  EngineImage? subjectMask(String path, {int? x, int? y});
  EngineImage? skyMask(String path);
  EngineImage? applyLut(String path, String lutPath, double strength);
  String? exportJpeg(String path, String dest, int quality);
}

final class ImageBufferNative extends Opaque {}

typedef _GetVersionN = Pointer<Utf8> Function();
typedef _GetVersionD = Pointer<Utf8> Function();
typedef _FreeStringN = Void Function(Pointer<Utf8>);
typedef _FreeStringD = void Function(Pointer<Utf8>);
typedef _CheckN = Int32 Function();
typedef _CheckD = int Function();
typedef _DevelopN = Pointer<ImageBufferNative> Function(Pointer<Utf8>);
typedef _DevelopD = Pointer<ImageBufferNative> Function(Pointer<Utf8>);
typedef _SubjectN = Pointer<ImageBufferNative> Function(Pointer<Utf8>, Int32, Int32, Int32);
typedef _SubjectD = Pointer<ImageBufferNative> Function(Pointer<Utf8>, int, int, int);
typedef _SkyN = Pointer<ImageBufferNative> Function(Pointer<Utf8>);
typedef _SkyD = Pointer<ImageBufferNative> Function(Pointer<Utf8>);
typedef _LutN = Pointer<ImageBufferNative> Function(Pointer<Utf8>, Pointer<Utf8>, Float);
typedef _LutD = Pointer<ImageBufferNative> Function(Pointer<Utf8>, Pointer<Utf8>, double);
typedef _ExportN = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Uint8);
typedef _ExportD = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _FreeBufN = Void Function(Pointer<ImageBufferNative>);
typedef _FreeBufD = void Function(Pointer<ImageBufferNative>);
typedef _GetU32N = Uint32 Function(Pointer<ImageBufferNative>);
typedef _GetU32D = int Function(Pointer<ImageBufferNative>);
typedef _GetLenN = UintPtr Function(Pointer<ImageBufferNative>);
typedef _GetLenD = int Function(Pointer<ImageBufferNative>);
typedef _GetDataN = Pointer<Uint8> Function(Pointer<ImageBufferNative>);
typedef _GetDataD = Pointer<Uint8> Function(Pointer<ImageBufferNative>);

class RawEngine implements StudioEngine {
  RawEngine._(this.lib) {
    _getVersion = lib.lookupFunction<_GetVersionN, _GetVersionD>('get_v7_version');
    _freeString = lib.lookupFunction<_FreeStringN, _FreeStringD>('free_string_rust');
    _check = lib.lookupFunction<_CheckN, _CheckD>('check_engine');
    _develop = lib.lookupFunction<_DevelopN, _DevelopD>('develop_raw');
    _subject = lib.lookupFunction<_SubjectN, _SubjectD>('detect_subject_mask');
    _sky = lib.lookupFunction<_SkyN, _SkyD>('detect_sky_mask_ffi');
    _lut = lib.lookupFunction<_LutN, _LutD>('apply_lut_file');
    _export = lib.lookupFunction<_ExportN, _ExportD>('export_jpeg_with_quality');
    _freeBuf = lib.lookupFunction<_FreeBufN, _FreeBufD>('free_image_buffer');
    _getW = lib.lookupFunction<_GetU32N, _GetU32D>('image_buffer_get_width');
    _getH = lib.lookupFunction<_GetU32N, _GetU32D>('image_buffer_get_height');
    _getLen = lib.lookupFunction<_GetLenN, _GetLenD>('image_buffer_get_len');
    _getData = lib.lookupFunction<_GetDataN, _GetDataD>('image_buffer_get_data');
    _lastErrorFn = lib.lookupFunction<_GetVersionN, _GetVersionD>('get_last_error');
  }

  final DynamicLibrary lib;
  late final _GetVersionD _getVersion;
  late final _FreeStringD _freeString;
  late final _CheckD _check;
  late final _DevelopD _develop;
  late final _SubjectD _subject;
  late final _SkyD _sky;
  late final _LutD _lut;
  late final _ExportD _export;
  late final _FreeBufD _freeBuf;
  late final _GetU32D _getW;
  late final _GetU32D _getH;
  late final _GetLenD _getLen;
  late final _GetDataD _getData;
  late final _GetVersionD _lastErrorFn;

  static RawEngine open() {
    if (Platform.isIOS || Platform.isMacOS) {
      return RawEngine._(DynamicLibrary.process());
    }
    if (Platform.isWindows) {
      return RawEngine._(DynamicLibrary.open('raw_engine.dll'));
    }
    return RawEngine._(DynamicLibrary.open('libraw_engine.so'));
  }

  @override
  bool checkEngine() => _check() == 1;

  @override
  String version() {
    final ptr = _getVersion();
    if (ptr == nullptr) return '';
    try {
      return ptr.toDartString();
    } finally {
      _freeString(ptr);
    }
  }

  @override
  String lastError() {
    final ptr = _lastErrorFn();
    if (ptr == nullptr) return 'Unknown Rust error';
    try {
      return ptr.toDartString();
    } finally {
      _freeString(ptr);
    }
  }

  @override
  EngineImage? develop(String path) => _withPath(path, _develop);

  @override
  EngineImage? subjectMask(String path, {int? x, int? y}) {
    final cPath = path.toNativeUtf8();
    try {
      final hasClick = x != null && y != null ? 1 : 0;
      return _copyBuffer(_subject(cPath, x ?? 0, y ?? 0, hasClick));
    } finally {
      calloc.free(cPath);
    }
  }

  @override
  EngineImage? skyMask(String path) => _withPath(path, _sky);

  @override
  EngineImage? applyLut(String path, String lutPath, double strength) {
    final cPath = path.toNativeUtf8();
    final cLut = lutPath.toNativeUtf8();
    try {
      return _copyBuffer(_lut(cPath, cLut, strength));
    } finally {
      calloc.free(cPath);
      calloc.free(cLut);
    }
  }

  @override
  String? exportJpeg(String path, String dest, int quality) {
    final cPath = path.toNativeUtf8();
    final cDest = dest.toNativeUtf8();
    try {
      final out = _export(cPath, cDest, quality.clamp(1, 100));
      if (out == nullptr) return null;
      try {
        return out.toDartString();
      } finally {
        _freeString(out);
      }
    } finally {
      calloc.free(cPath);
      calloc.free(cDest);
    }
  }

  EngineImage? _withPath(String path, _DevelopD fn) {
    final cPath = path.toNativeUtf8();
    try {
      return _copyBuffer(fn(cPath));
    } finally {
      calloc.free(cPath);
    }
  }

  EngineImage? _copyBuffer(Pointer<ImageBufferNative> ptr) {
    if (ptr == nullptr) return null;
    try {
      final width = _getW(ptr);
      final height = _getH(ptr);
      final length = _getLen(ptr);
      final expected = width * height * 4;
      if (width <= 0 || height <= 0 || length != expected) {
        throw StateError(
          'Invalid RGBA buffer metadata: ${width}x$height len=$length expected=$expected',
        );
      }
      final dataPtr = _getData(ptr);
      if (dataPtr == nullptr) {
        throw StateError('Rust returned null data pointer');
      }
      return EngineImage(
        Uint8List.fromList(dataPtr.asTypedList(length)),
        width,
        height,
      );
    } finally {
      _freeBuf(ptr);
    }
  }
}

Uint8List rgbaToPng(EngineImage image) {
  final decoded = img.Image.fromBytes(
    width: image.width,
    height: image.height,
    bytes: image.rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodePng(decoded));
}
