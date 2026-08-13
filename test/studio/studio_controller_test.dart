import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/engine/engine_image.dart';
import 'package:nixin_studio_v8/engine/raw_engine.dart';
import 'package:nixin_studio_v8/studio/develop_preview_renderer.dart';
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
      expect(controller.state.exposure, 0);
      expect(controller.state.temperature, 0);
      expect(controller.state.contrast, 1);
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

    test('keyboard visibility actions toggle side panels and chrome', () {
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
      );

      controller.toggleSidePanels();
      expect(controller.state.leftPanelVisible, isFalse);
      expect(controller.state.rightPanelVisible, isFalse);

      controller.toggleSidePanels();
      expect(controller.state.leftPanelVisible, isTrue);
      expect(controller.state.rightPanelVisible, isTrue);

      controller.toggleChrome();
      expect(controller.state.chromeVisible, isFalse);
      controller.toggleChrome();
      expect(controller.state.chromeVisible, isTrue);
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

    test('selecting another RAW clears preview, zoom, and adjustments', () async {
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
      );

      controller.selectRawPath('/tmp/first.nef');
      controller.setExposure(1.5);
      controller.setTemperature(0.4);
      controller.setContrast(1.3);
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
      expect(controller.state.exposure, 0);
      expect(controller.state.temperature, 0);
      expect(controller.state.contrast, 1);
    });

    test('develop forwards adjustments and publishes preview', () async {
      final engine = _FakeEngine();
      final controller = StudioController(
        engine: engine,
        settings: _MemorySettings(),
      );
      controller.selectRawPath('/tmp/sample.nef');
      controller.setExposure(1.25);
      controller.setTemperature(-0.35);
      controller.setContrast(1.4);

      await controller.develop();

      expect(engine.lastDevelopPath, '/tmp/sample.nef');
      expect(engine.lastExposure, 1.25);
      expect(engine.lastTemperature, -0.35);
      expect(engine.lastContrast, 1.4);
      expect(controller.state.previewStatus, PreviewStatus.ready);
      expect(controller.state.imageWidth, 1);
      expect(controller.state.imageHeight, 1);
      expect(controller.state.previewPng, isNotEmpty);
      expect(controller.state.statusMessage, 'ready');
    });

    test('adjustments clamp and reset to engine defaults', () async {
      final engine = _FakeEngine();
      final controller = StudioController(
        engine: engine,
        settings: _MemorySettings(),
      );
      controller.selectRawPath('/tmp/sample.nef');

      controller.setExposure(99);
      controller.setTemperature(-99);
      controller.setContrast(99);

      expect(controller.state.exposure, 4);
      expect(controller.state.temperature, -1);
      expect(controller.state.contrast, 2);
      expect(controller.state.hasDevelopAdjustments, isTrue);

      await controller.resetDevelopAdjustments();

      expect(controller.state.exposure, 0);
      expect(controller.state.temperature, 0);
      expect(controller.state.contrast, 1);
      expect(controller.state.hasDevelopAdjustments, isFalse);
      expect(engine.lastExposure, 0);
      expect(engine.lastTemperature, 0);
      expect(engine.lastContrast, 1);
    });

    test('coalesces rapid interactive previews and drops stale results', () async {
      final renderer = _ControlledPreviewRenderer();
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
        previewRenderer: renderer,
        interactivePreviewInterval: Duration.zero,
      );
      controller.selectRawPath('/tmp/sample.nef');

      controller.previewExposure(0.5);
      await _flushAsync();
      expect(renderer.requests, hasLength(1));
      expect(renderer.requests.single.exposure, 0.5);

      controller.previewExposure(1.0);
      controller.previewExposure(1.5);
      expect(renderer.requests, hasLength(1));

      renderer.complete(0);
      await _flushAsync();

      expect(controller.state.previewPng, isNull);
      expect(renderer.requests, hasLength(2));
      expect(renderer.requests.last.exposure, 1.5);

      renderer.complete(1);
      await _flushAsync();

      expect(controller.state.previewStatus, PreviewStatus.ready);
      expect(controller.state.previewPng, isNotEmpty);
      expect(controller.state.exposure, 1.5);
    });

    test('slider release renders exact committed values after stale work', () async {
      final renderer = _ControlledPreviewRenderer();
      final controller = StudioController(
        engine: _FakeEngine(),
        settings: _MemorySettings(),
        previewRenderer: renderer,
        interactivePreviewInterval: Duration.zero,
      );
      controller.selectRawPath('/tmp/sample.nef');

      controller.previewContrast(1.1);
      await _flushAsync();
      expect(renderer.requests, hasLength(1));

      controller.previewContrast(1.65);
      final committed = controller.commitDevelopAdjustments();

      renderer.complete(0);
      await _flushAsync();

      expect(renderer.requests, hasLength(2));
      expect(renderer.requests.last.contrast, 1.65);
      expect(controller.state.previewPng, isNull);

      renderer.complete(1);
      await committed;
      await _flushAsync();

      expect(controller.state.contrast, 1.65);
      expect(controller.state.previewStatus, PreviewStatus.ready);
      expect(controller.state.previewPng, isNotEmpty);
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

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
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

class _ControlledPreviewRenderer implements DevelopPreviewRenderer {
  final List<DevelopPreviewRequest> requests = [];
  final List<Completer<DevelopPreviewResult>> _completers = [];

  @override
  Future<DevelopPreviewResult> render(DevelopPreviewRequest request) {
    requests.add(request);
    final completer = Completer<DevelopPreviewResult>();
    _completers.add(completer);
    return completer.future;
  }

  void complete(int index) {
    _completers[index].complete(
      DevelopPreviewResult.success(
        EngineImage(
          Uint8List.fromList(const [32, 64, 96, 255]),
          1,
          1,
        ),
      ),
    );
  }
}

class _FakeEngine implements StudioEngine {
  _FakeEngine({this.returnNullDevelop = false});

  final bool returnNullDevelop;
  String? lastDevelopPath;
  double? lastExposure;
  double? lastTemperature;
  double? lastContrast;

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
  EngineImage? develop(
    String path, {
    double exposure = 0,
    double temperature = 0,
    double contrast = 1,
  }) {
    lastDevelopPath = path;
    lastExposure = exposure;
    lastTemperature = temperature;
    lastContrast = contrast;
    return returnNullDevelop ? null : _image;
  }

  @override
  String? exportJpeg(
    String path,
    String dest,
    int quality, {
    double exposure = 0,
    double temperature = 0,
    double contrast = 1,
  }) => dest;

  @override
  String lastError() => 'fake engine error';

  @override
  EngineImage? skyMask(String path) => _image;

  @override
  EngineImage? subjectMask(String path, {int? x, int? y}) => _image;

  @override
  String version() => 'fake-1.0';
}
