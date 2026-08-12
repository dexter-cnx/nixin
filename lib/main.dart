import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

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
typedef _GetLenN = Size Function(Pointer<ImageBufferNative>);
typedef _GetLenD = int Function(Pointer<ImageBufferNative>);
typedef _GetDataN = Pointer<Uint8> Function(Pointer<ImageBufferNative>);
typedef _GetDataD = Pointer<Uint8> Function(Pointer<ImageBufferNative>);

class EngineImage {
  const EngineImage(this.rgba, this.width, this.height);
  final Uint8List rgba;
  final int width;
  final int height;
}

class RawEngine {
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
  late final _GetU32D _getW, _getH;
  late final _GetLenD _getLen;
  late final _GetDataD _getData;
  late final _GetVersionD _lastErrorFn;

  static RawEngine open() {
    if (Platform.isIOS) return RawEngine._(DynamicLibrary.process());
    if (Platform.isWindows) return RawEngine._(DynamicLibrary.open('raw_engine.dll'));
    if (Platform.isMacOS) return RawEngine._(DynamicLibrary.open('libraw_engine.dylib'));
    if (Platform.isAndroid) return RawEngine._(DynamicLibrary.open('libraw_engine.so'));
    return RawEngine._(DynamicLibrary.open('libraw_engine.so'));
  }

  bool checkEngine() => _check() == 1;

  String version() {
    final ptr = _getVersion();
    if (ptr == nullptr) return '';
    try { return ptr.toDartString(); } finally { _freeString(ptr); }
  }

  String lastError() {
    final ptr = _lastErrorFn();
    if (ptr == nullptr) return 'Unknown Rust error';
    try { return ptr.toDartString(); } finally { _freeString(ptr); }
  }

  EngineImage? develop(String path) => _withPath(path, _develop);

  EngineImage? subjectMask(String path, {int? x, int? y}) {
    final cPath = path.toNativeUtf8();
    try {
      final hasClick = x != null && y != null ? 1 : 0;
      final ptr = _subject(cPath, x ?? 0, y ?? 0, hasClick);
      return _copyBuffer(ptr);
    } finally { calloc.free(cPath); }
  }

  EngineImage? skyMask(String path) => _withPath(path, _sky);

  EngineImage? applyLut(String path, String lutPath, double strength) {
    final cPath = path.toNativeUtf8();
    final cLut = lutPath.toNativeUtf8();
    try { return _copyBuffer(_lut(cPath, cLut, strength)); }
    finally { calloc.free(cPath); calloc.free(cLut); }
  }

  String? exportJpeg(String path, String dest, int quality) {
    final cPath = path.toNativeUtf8();
    final cDest = dest.toNativeUtf8();
    try {
      final out = _export(cPath, cDest, quality.clamp(1, 100));
      if (out == nullptr) return null;
      try { return out.toDartString(); } finally { _freeString(out); }
    } finally { calloc.free(cPath); calloc.free(cDest); }
  }

  EngineImage? _withPath(String path, _DevelopD fn) {
    final cPath = path.toNativeUtf8();
    try { return _copyBuffer(fn(cPath)); } finally { calloc.free(cPath); }
  }

  EngineImage? _copyBuffer(Pointer<ImageBufferNative> ptr) {
    if (ptr == nullptr) return null;
    try {
      final w = _getW(ptr), h = _getH(ptr), len = _getLen(ptr);
      final expected = w * h * 4;
      if (w <= 0 || h <= 0 || len != expected) {
        throw StateError('Invalid RGBA buffer metadata: ${w}x$h len=$len expected=$expected');
      }
      final dataPtr = _getData(ptr);
      if (dataPtr == nullptr) throw StateError('Rust returned null data pointer');
      return EngineImage(Uint8List.fromList(dataPtr.asTypedList(len)), w, h);
    } finally { _freeBuf(ptr); }
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

void main() => runApp(const NixinApp());

class NixinApp extends StatelessWidget {
  const NixinApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(debugShowCheckedModeBanner:false, theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:Colors.indigo),useMaterial3:true), home:const StudioPage());
}

class StudioPage extends StatefulWidget { const StudioPage({super.key}); @override State<StudioPage> createState()=>_StudioPageState(); }
class _StudioPageState extends State<StudioPage> {
  RawEngine? engine; String? rawPath; EngineImage? shown; Uint8List? png; String status='Engine not loaded'; int quality=90;

  @override void initState(){ super.initState(); try { engine=RawEngine.open(); status='${engine!.version()} • check=${engine!.checkEngine()}'; } catch(e){ status='Engine load failed: $e'; } }

  Future<void> pickRaw() async { final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['arw','cr2','cr3','nef','dng','raf','orf']); if(r?.files.single.path!=null) setState((){rawPath=r!.files.single.path; status='Selected ${p.basename(rawPath!)}';}); }
  void showResult(EngineImage? result){ if(result==null){setState(()=>status=engine?.lastError()??'Engine unavailable');return;} final bytes=rgbaToPng(result); setState((){shown=result;png=bytes;status='Image ${result.width}×${result.height} • ${result.rgba.length} RGBA bytes';}); }
  Future<void> develop() async { if(rawPath==null||engine==null)return; showResult(engine!.develop(rawPath!)); }
  Future<void> subject() async { if(rawPath==null||engine==null)return; showResult(engine!.subjectMask(rawPath!)); }
  Future<void> sky() async { if(rawPath==null||engine==null)return; showResult(engine!.skyMask(rawPath!)); }
  Future<void> lut() async { if(rawPath==null||engine==null)return; final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['cube']); final lp=r?.files.single.path; if(lp!=null)showResult(engine!.applyLut(rawPath!,lp,1.0)); }
  Future<void> export() async { if(rawPath==null||engine==null)return; final dest=await FilePicker.platform.saveFile(dialogTitle:'Export JPEG',fileName='nixin-export.jpg',type:FileType.custom,allowedExtensions:const ['jpg','jpeg']); if(dest==null)return; final out=engine!.exportJpeg(rawPath!,dest,quality); setState(()=>status=out??engine!.lastError()); }

  @override Widget build(BuildContext context){ return Scaffold(appBar:AppBar(title:const Text('Nixin Studio V8')),body:SafeArea(child:Column(children:[Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:8,runSpacing:8,children:[FilledButton(onPressed:pickRaw,child:const Text('Open RAW')),FilledButton(onPressed:rawPath==null?null:develop,child:const Text('Develop')),OutlinedButton(onPressed:rawPath==null?null:subject,child:const Text('Subject Mask')),OutlinedButton(onPressed:rawPath==null?null:sky,child:const Text('Sky Mask')),OutlinedButton(onPressed:rawPath==null?null:lut,child:const Text('Apply .cube LUT')),OutlinedButton(onPressed:rawPath==null?null:export,child:const Text('Export JPEG')),SizedBox(width:180,child:Row(children:[const Text('Q'),Expanded(child:Slider(value:quality.toDouble(),min:1,max:100,divisions:99,label:'$quality',onChanged:(v)=>setState(()=>quality=v.round())))]) )])),Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Align(alignment:Alignment.centerLeft,child:Text(status))),const SizedBox(height:8),Expanded(child:Container(width:double.infinity,color:Colors.black12,alignment:Alignment.center,child:png==null?const Text('Open a RAW file and press Develop'):InteractiveViewer(child:Image.memory(png!,fit:BoxFit.contain,gaplessPlayback:true))))]))); }
}
