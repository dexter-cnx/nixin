import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../engine/engine_image.dart';
import '../engine/raw_engine.dart';
import 'develop_preview_renderer.dart';
import 'studio_state.dart';

abstract interface class StudioSettingsStore {
  T read<T>(String key, T defaultValue);
  Future<void> write(String key, Object value);
}

class HiveStudioSettingsStore implements StudioSettingsStore {
  HiveStudioSettingsStore(this.box);
  final Box<dynamic> box;

  @override
  T read<T>(String key, T defaultValue) =>
      box.get(key, defaultValue: defaultValue) as T;

  @override
  Future<void> write(String key, Object value) => box.put(key, value);
}

final studioSettingsBoxProvider = Provider<Box<dynamic>>((ref) {
  return Hive.box<dynamic>('studio_settings');
});

final studioSettingsStoreProvider = Provider<StudioSettingsStore>((ref) {
  return HiveStudioSettingsStore(ref.watch(studioSettingsBoxProvider));
});

final studioEngineProvider = Provider<StudioEngine?>((ref) {
  try {
    return RawEngine.open();
  } catch (_) {
    return null;
  }
});

final studioDevelopPreviewRendererProvider = Provider<DevelopPreviewRenderer>(
  (ref) => const IsolateDevelopPreviewRenderer(),
);

final studioControllerProvider =
    StateNotifierProvider<StudioController, StudioState>((ref) {
  return StudioController(
    engine: ref.watch(studioEngineProvider),
    settings: ref.watch(studioSettingsStoreProvider),
    previewRenderer: ref.watch(studioDevelopPreviewRendererProvider),
  );
});

class StudioController extends StateNotifier<StudioState> {
  StudioController({
    required StudioEngine? engine,
    required StudioSettingsStore settings,
    DevelopPreviewRenderer? previewRenderer,
    Duration interactivePreviewInterval = const Duration(milliseconds: 75),
  })  : _engine = engine,
        _settings = settings,
        _previewRenderer = previewRenderer ?? DirectDevelopPreviewRenderer(engine),
        _interactivePreviewInterval = interactivePreviewInterval,
        super(
          StudioState(
            exportQuality: settings.read<int>('exportQuality', 90),
            activeModule: _restoreModule(settings),
            leftPanelVisible: settings.read<bool>('leftPanelVisible', true),
            rightPanelVisible: settings.read<bool>('rightPanelVisible', true),
            filmstripVisible: settings.read<bool>('filmstripVisible', true),
          ),
        ) {
    _initializeEngine();
  }

  final StudioEngine? _engine;
  final StudioSettingsStore _settings;
  final DevelopPreviewRenderer _previewRenderer;
  final Duration _interactivePreviewInterval;

  Timer? _previewTimer;
  _QueuedDevelopPreview? _pendingDevelopPreview;
  bool _developRenderInFlight = false;
  bool _disposed = false;
  int _developRevision = 0;
  DateTime? _lastDevelopRenderStartedAt;

  static StudioModule _restoreModule(StudioSettingsStore settings) {
    final index = settings.read<int>(
      'activeModule',
      StudioModule.develop.index,
    );
    if (index < 0 || index >= StudioModule.values.length) {
      return StudioModule.develop;
    }
    return StudioModule.values[index];
  }

  void _initializeEngine() {
    if (_engine == null) {
      state = state.copyWith(
        engineReady: false,
        statusMessage: 'engine_unavailable',
      );
      return;
    }
    try {
      state = state.copyWith(
        engineReady: _engine.checkEngine(),
        engineVersion: _engine.version(),
        statusMessage: 'ready',
      );
    } catch (error) {
      state = state.copyWith(
        engineReady: false,
        previewStatus: PreviewStatus.error,
        errorMessage: '$error',
        statusMessage: 'engine_unavailable',
      );
    }
  }

  Future<void> setModule(StudioModule module) async {
    state = state.copyWith(activeModule: module);
    await _settings.write('activeModule', module.index);
  }

  Future<void> toggleLeftPanel() async {
    final next = !state.leftPanelVisible;
    state = state.copyWith(leftPanelVisible: next);
    await _settings.write('leftPanelVisible', next);
  }

  Future<void> toggleRightPanel() async {
    final next = !state.rightPanelVisible;
    state = state.copyWith(rightPanelVisible: next);
    await _settings.write('rightPanelVisible', next);
  }

  void toggleSidePanels() {
    final anyVisible = state.leftPanelVisible || state.rightPanelVisible;
    state = state.copyWith(
      leftPanelVisible: !anyVisible,
      rightPanelVisible: !anyVisible,
    );
  }

  void toggleChrome() {
    state = state.copyWith(chromeVisible: !state.chromeVisible);
  }

  Future<void> toggleFilmstrip() async {
    final next = !state.filmstripVisible;
    state = state.copyWith(filmstripVisible: next);
    await _settings.write('filmstripVisible', next);
  }

  void setPreviewZoomMode(PreviewZoomMode mode) {
    state = state.copyWith(previewZoomMode: mode);
  }

  Future<void> setExportQuality(int quality) async {
    final next = quality.clamp(1, 100).toInt();
    state = state.copyWith(exportQuality: next);
    await _settings.write('exportQuality', next);
  }

  void setExposure(double value) {
    state = state.copyWith(exposure: value.clamp(-4.0, 4.0).toDouble());
  }

  void previewExposure(double value) {
    setExposure(value);
    _queueInteractiveDevelopPreview();
  }

  void setTemperature(double value) {
    state = state.copyWith(
      temperature: value.clamp(-1.0, 1.0).toDouble(),
    );
  }

  void previewTemperature(double value) {
    setTemperature(value);
    _queueInteractiveDevelopPreview();
  }

  void setContrast(double value) {
    state = state.copyWith(contrast: value.clamp(0.0, 2.0).toDouble());
  }

  void previewContrast(double value) {
    setContrast(value);
    _queueInteractiveDevelopPreview();
  }

  Future<void> commitDevelopAdjustments() => _queueDevelopPreview(
        finalCommit: true,
      );

  Future<void> resetDevelopAdjustments() async {
    state = state.copyWith(exposure: 0, temperature: 0, contrast: 1);
    if (state.rawPath != null) await develop();
  }

  void selectRawPath(String path) {
    _invalidateDevelopQueue();
    state = state.copyWith(
      rawPath: path,
      clearPreview: true,
      previewStatus: PreviewStatus.empty,
      previewZoomMode: PreviewZoomMode.fit,
      exposure: 0,
      temperature: 0,
      contrast: 1,
      clearError: true,
      statusMessage: 'selected',
    );
  }

  Future<void> pickRaw() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'arw',
        'cr2',
        'cr3',
        'nef',
        'dng',
        'raf',
        'orf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'tif',
        'tiff',
        'bmp',
        'gif',
      ],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    selectRawPath(path);
    await develop();
  }

  Future<void> develop() => _queueDevelopPreview(finalCommit: true);

  Future<void> subjectMask() async {
    _invalidateDevelopQueue();
    await _runImageOperation((engine, path) => engine.subjectMask(path));
  }

  Future<void> skyMask() async {
    _invalidateDevelopQueue();
    await _runImageOperation((engine, path) => engine.skyMask(path));
  }

  Future<void> applyLut() async {
    final engine = _engine;
    final path = state.rawPath;
    if (engine == null || path == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['cube'],
    );
    final lutPath = result?.files.single.path;
    if (lutPath == null) return;
    _invalidateDevelopQueue();
    await _runImageOperation(
      (currentEngine, currentPath) =>
          currentEngine.applyLut(currentPath, lutPath, 1.0),
    );
  }

  Future<void> exportJpeg() async {
    final engine = _engine;
    final path = state.rawPath;
    if (engine == null || path == null) return;
    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Export JPEG',
      fileName: 'nixin-export.jpg',
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg'],
    );
    if (destination == null) return;
    state = state.copyWith(
      previewStatus: PreviewStatus.processing,
      clearError: true,
    );
    try {
      final output = engine.exportJpeg(
        path,
        destination,
        state.exportQuality,
        exposure: state.exposure,
        temperature: state.temperature,
        contrast: state.contrast,
      );
      if (output == null) {
        _setEngineError(engine);
        return;
      }
      state = state.copyWith(
        previewStatus: state.previewPng == null
            ? PreviewStatus.empty
            : PreviewStatus.ready,
        statusMessage: 'exported',
      );
    } catch (error) {
      state = state.copyWith(
        previewStatus: PreviewStatus.error,
        errorMessage: '$error',
      );
    }
  }

  void _queueInteractiveDevelopPreview() {
    if (state.rawPath == null || _engine == null) return;
    unawaited(_queueDevelopPreview(finalCommit: false));
  }

  Future<void> _queueDevelopPreview({required bool finalCommit}) {
    final path = state.rawPath;
    if (_engine == null || path == null) return Future<void>.value();

    final revision = ++_developRevision;
    final completer = finalCommit ? Completer<void>() : null;
    final queued = _QueuedDevelopPreview(
      request: DevelopPreviewRequest(
        path: path,
        exposure: state.exposure,
        temperature: state.temperature,
        contrast: state.contrast,
      ),
      revision: revision,
      finalCommit: finalCommit,
      completer: completer,
    );

    _completeQueuedCommit(_pendingDevelopPreview);
    _pendingDevelopPreview = queued;

    if (finalCommit) {
      _previewTimer?.cancel();
      _previewTimer = null;
      _startPendingDevelopPreview();
    } else {
      _schedulePendingDevelopPreview();
    }

    return completer?.future ?? Future<void>.value();
  }

  void _schedulePendingDevelopPreview() {
    if (_disposed ||
        _developRenderInFlight ||
        _previewTimer?.isActive == true ||
        _pendingDevelopPreview == null) {
      return;
    }

    var delay = _interactivePreviewInterval;
    final lastStarted = _lastDevelopRenderStartedAt;
    if (lastStarted != null) {
      final elapsed = DateTime.now().difference(lastStarted);
      if (elapsed >= _interactivePreviewInterval) {
        delay = Duration.zero;
      } else {
        delay = _interactivePreviewInterval - elapsed;
      }
    }

    _previewTimer = Timer(delay, () {
      _previewTimer = null;
      _startPendingDevelopPreview();
    });
  }

  void _startPendingDevelopPreview() {
    if (_disposed || _developRenderInFlight) return;
    final queued = _pendingDevelopPreview;
    if (queued == null) return;

    _pendingDevelopPreview = null;
    _developRenderInFlight = true;
    _lastDevelopRenderStartedAt = DateTime.now();
    if (state.previewPng == null) {
      state = state.copyWith(
        previewStatus: PreviewStatus.processing,
        clearError: true,
      );
    }
    unawaited(_runDevelopPreview(queued));
  }

  Future<void> _runDevelopPreview(_QueuedDevelopPreview queued) async {
    DevelopPreviewResult result;
    try {
      result = await _previewRenderer.render(queued.request);
    } catch (error) {
      result = DevelopPreviewResult.failure('$error');
    }

    if (!_disposed && queued.revision == _developRevision) {
      final image = result.image;
      if (image == null) {
        state = state.copyWith(
          previewStatus: PreviewStatus.error,
          errorMessage: result.error ?? 'Unknown preview render error',
        );
      } else {
        state = state.copyWith(
          previewPng: rgbaToPng(image),
          imageWidth: image.width,
          imageHeight: image.height,
          previewStatus: PreviewStatus.ready,
          clearError: true,
          statusMessage: 'ready',
        );
      }
    }

    _completeQueuedCommit(queued);
    _developRenderInFlight = false;

    final pending = _pendingDevelopPreview;
    if (_disposed || pending == null) return;
    if (pending.finalCommit) {
      _previewTimer?.cancel();
      _previewTimer = null;
      _startPendingDevelopPreview();
    } else {
      _schedulePendingDevelopPreview();
    }
  }

  void _invalidateDevelopQueue() {
    _developRevision++;
    _previewTimer?.cancel();
    _previewTimer = null;
    _completeQueuedCommit(_pendingDevelopPreview);
    _pendingDevelopPreview = null;
  }

  void _completeQueuedCommit(_QueuedDevelopPreview? queued) {
    final completer = queued?.completer;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _runImageOperation(EngineImageOperation operation) async {
    final engine = _engine;
    final path = state.rawPath;
    if (engine == null || path == null) return;
    state = state.copyWith(
      previewStatus: PreviewStatus.processing,
      clearError: true,
    );
    try {
      final image = operation(engine, path);
      if (image == null) {
        _setEngineError(engine);
        return;
      }
      state = state.copyWith(
        previewPng: rgbaToPng(image),
        imageWidth: image.width,
        imageHeight: image.height,
        previewStatus: PreviewStatus.ready,
        clearError: true,
        statusMessage: 'ready',
      );
    } catch (error) {
      state = state.copyWith(
        previewStatus: PreviewStatus.error,
        errorMessage: '$error',
      );
    }
  }

  void _setEngineError(StudioEngine engine) {
    state = state.copyWith(
      previewStatus: PreviewStatus.error,
      errorMessage: engine.lastError(),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _invalidateDevelopQueue();
    super.dispose();
  }
}

class _QueuedDevelopPreview {
  const _QueuedDevelopPreview({
    required this.request,
    required this.revision,
    required this.finalCommit,
    required this.completer,
  });

  final DevelopPreviewRequest request;
  final int revision;
  final bool finalCommit;
  final Completer<void>? completer;
}

typedef EngineImageOperation = EngineImage? Function(
  StudioEngine engine,
  String path,
);
