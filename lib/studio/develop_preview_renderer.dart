import 'dart:isolate';

import '../engine/engine_image.dart';
import '../engine/raw_engine.dart';

class DevelopPreviewRequest {
  const DevelopPreviewRequest({
    required this.path,
    required this.exposure,
    required this.temperature,
    required this.contrast,
  });

  final String path;
  final double exposure;
  final double temperature;
  final double contrast;
}

class DevelopPreviewResult {
  const DevelopPreviewResult._({this.image, this.error});

  const DevelopPreviewResult.success(EngineImage image)
      : this._(image: image);

  const DevelopPreviewResult.failure(String error)
      : this._(error: error);

  final EngineImage? image;
  final String? error;
}

abstract interface class DevelopPreviewRenderer {
  Future<DevelopPreviewResult> render(DevelopPreviewRequest request);
}

class IsolateDevelopPreviewRenderer implements DevelopPreviewRenderer {
  const IsolateDevelopPreviewRenderer();

  @override
  Future<DevelopPreviewResult> render(DevelopPreviewRequest request) {
    return Isolate.run(() => _renderDevelopPreview(request));
  }
}

class DirectDevelopPreviewRenderer implements DevelopPreviewRenderer {
  const DirectDevelopPreviewRenderer(this.engine);

  final StudioEngine? engine;

  @override
  Future<DevelopPreviewResult> render(DevelopPreviewRequest request) async {
    final currentEngine = engine;
    if (currentEngine == null) {
      return const DevelopPreviewResult.failure('Engine unavailable');
    }
    return _renderWithEngine(currentEngine, request);
  }
}

DevelopPreviewResult _renderDevelopPreview(DevelopPreviewRequest request) {
  try {
    return _renderWithEngine(RawEngine.open(), request);
  } catch (error) {
    return DevelopPreviewResult.failure('$error');
  }
}

DevelopPreviewResult _renderWithEngine(
  StudioEngine engine,
  DevelopPreviewRequest request,
) {
  try {
    final image = engine.develop(
      request.path,
      exposure: request.exposure,
      temperature: request.temperature,
      contrast: request.contrast,
    );
    if (image == null) {
      return DevelopPreviewResult.failure(engine.lastError());
    }
    return DevelopPreviewResult.success(image);
  } catch (error) {
    return DevelopPreviewResult.failure('$error');
  }
}
