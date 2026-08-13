import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../engine/engine_image.dart';
import '../engine/raw_engine.dart';
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

final studioControllerProvider =
    StateNotifierProvider<StudioController, StudioState>((ref) {
  return StudioController(
    engine: ref.watch(studioEngineProvider),
    settings: ref.watch(studioSettingsStoreProvider),
  );
});

class StudioController extends StateNotifier<StudioState> {
  StudioController({
    required StudioEngine? engine,
    required StudioSettingsStore settings,
  })  : _engine = engine,
        _settings = settings,
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

  void selectRawPath(String path) {
    state = state.copyWith(
      rawPath: path,
      clearPreview: true,
      previewStatus: PreviewStatus.empty,
      previewZoomMode: PreviewZoomMode.fit,
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
      ],
    );
    final path = result?.files.single.path;
    if (path != null) selectRawPath(path);
  }

  Future<void> develop() async =>
      _runImageOperation((engine, path) => engine.develop(path));

  Future<void> subjectMask() async =>
      _runImageOperation((engine, path) => engine.subjectMask(path));

  Future<void> skyMask() async =>
      _runImageOperation((engine, path) => engine.skyMask(path));

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
      final output = engine.exportJpeg(path, destination, state.exportQuality);
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
}

typedef EngineImageOperation = EngineImage? Function(
  StudioEngine engine,
  String path,
);
