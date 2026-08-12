import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/engine/engine_image.dart';
import 'package:nixin_studio_v8/engine/raw_engine.dart';
import 'package:nixin_studio_v8/studio/studio_controller.dart';
import 'package:nixin_studio_v8/studio/studio_state.dart';

void main() {
  group('StudioController', () {
    test('restores persisted workspace preferences', () {
      final settings = _MemorySettings({
        'exportQuality': 74,
        'activeModule': StudioModule.library.index,
        'leftPanelVisible': false,
        'rightPanelVisible': true,
        'filmstripVisible': false,
      });

      final controller = StudioController(
        engine: _FakeEngine(),
        settings: settings,
      );

      expect(controller.state.exportQuality, 74);
      expect(controller.state.activeModule, StudioModule.library);
      expect(controller.state.leftPanelVisible, isFalse);
      expect(controller.state.rightPanelVisible, isTrue);
      expect(controller.state.filmstripVisible, isFalse);
      expect(controller.state.engineReady, isTrue);
      expect(controller.state.engineVersion, 'fake-1.0');
    });

    test('persists workspace visibility and clamped export quality', () async {
      final settings = _MemorySettings();
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: settings,
      );

      await controller.setModule(StudioModule.export);
      await controller.toggleLeftPanel();
      await controller.toggleRightPanel();
      await controller.toggleFilmstrip();
      await controller.setExportQuality(120);

      expect(settings.values['activeModule'], StudioModule.export.index);
      expect(settings.values['leftPanelVisible'], isFalse);
      expect(settings.values['rightPanelVisible'], isFalse);
      expect(settings.values['filmstripVisible'], isFalse);
      expect(settings.values['exportQuality'], 100);
      expect(controller.state.exportQuality, 100);
    });

    test('changes preview zoom mode without touching engine state', () {
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
      );

      controller.setPreviewZoomMode(PreviewZoomMode.oneToOne);

      expect(controller.state.previewZoomMode, PreviewZoomMode.oneToOne);
      expect(controller.state.engineReady, isTrue);
    });

    test('selecting another RAW clears an old preview and resets zoom', () async {
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
      );

      controller.selectRawPath('/tmp/first.nef');
      await controller.develop();
      controller.setPreviewZoomMode(PreviewZoomMode.oneToOne);
      expect(controller.state.previewStatus, PreviewStatus.ready);
      expect(controller.state.previewPng, isNotNull);

      controller.selectRawPath('/tmp/second.nef');

      expect(controller.state.rawPath, '/tmp/second.nef');
      expect(controller.state.previewStatus, PreviewStatus.empty);
      expect(controller.state.previewPng, isNull);
      expect(controller.state.imageWidth, isNull);
      expect(controller.state.imageHeight, isNull);
      expect(controller.state.previewZoomMode, PreviewZoomMode.fit);
    });

    test('develop routes through the injected engine and publishes preview', () async {
      final engine = _FakeEngine();
      final controller = StudioController(
        engine: engine,
        settings: _MemorySettings(),
      );
      controller.selectRawPath('/tmp/sample.nef');

      await controller.develop();

      expect(engine.lastDevelopPath, '/tmp/sample.nef');
      expect(controller.state.previewStatus, PreviewStatus.ready);
      expect(controller.state.imageWidth, 1);
      expect(controller.state.imageHeight, 1);
      expect(controller.state.previewPng, isNotEmpty);
      expect(controller.state.statusMessage, 'ready');
    });

    test('engine errors become explicit preview error state', () async {
      final controller = StudioController(
        engine: _FakeEngine(returnNullDevelop: true),
        settings: _MemorySettings(),
      );
      controller.selectRawPath('/tmp/bad.nef');

      await controller.develop();

      expect(controller.state.previewStatus, PreviewStatus.error);
      expect(controller.state.errorMessage, 'fake engine error');
    });

    test('missing engine is represented without throwing', () {
      final controller = StudioController(
        engine: null,
        settings: _MemorySettings(),
      );

      expect(controller.state.engineReady, isFalse);
      expect(controller.state.statusMessage, 'engine_unavailable');
    });
  });
}

class _MemorySettings implements StudioSettingsStore {
  _MemorySettings([Map<String, Object>? initial])
      : values = Map<String, Object>.from(initial ?? const {});

  final Map<String, Object> values;

  @override
  T read<T>(String key, T defaultValue) =>
      (values[key] ?? defaultValue) as T;

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }
}

class _FakeEngine implements StudioEngine {
  _FakeEngine({this.returnNullDevelop = false});

  final bool returnNullDevelop;
  String? lastDevelopPath;

  EngineImage get _image => EngineImage(
        Uint8List.fromList(const [32, 64, 96, 255]),
        1,
        1,
      );

  @override
  EngineImage? applyLut(String path, String lutPath, double strength) => _image;

  @override
  bool checkEngine() => true;

  @override
  EngineImage? develop(String path) {
    lastDevelopPath = path;
    return returnNullDevelop ? null : _image;
  }

  @override
  String? exportJpeg(String path, String dest, int quality) => dest;

  @override
  String lastError() => 'fake engine error';

  @override
  EngineImage? skyMask(String path) => _image;

  @override
  EngineImage? subjectMask(String path, {int? x, int? y}) => _image;

  @override
  String version() => 'fake-1.0';
}
