import 'dart:typed_data';

import 'package:path/path.dart' as p;

enum StudioModule { library, develop, export }

enum PreviewStatus { empty, processing, ready, error }

enum PreviewZoomMode { fit, oneToOne }

enum StudioLayoutMode { wide, medium, compact }

abstract final class StudioLayoutBreakpoints {
  static const compactMax = 799.0;
  static const sidePanelsMin = 1100.0;
  static const fullWorkspaceMin = 1440.0;
}

abstract final class StudioLayoutRatios {
  static const wideLeft = 18;
  static const wideCenter = 60;
  static const wideRight = 22;
  static const mediumCenter = 70;
  static const mediumRight = 30;
}

class StudioState {
  const StudioState({
    this.engineReady = false,
    this.engineVersion = '',
    this.rawPath,
    this.previewPng,
    this.imageWidth,
    this.imageHeight,
    this.previewStatus = PreviewStatus.empty,
    this.previewZoomMode = PreviewZoomMode.fit,
    this.errorMessage,
    this.statusMessage,
    this.exportQuality = 90,
    this.activeModule = StudioModule.develop,
    this.leftPanelVisible = true,
    this.rightPanelVisible = true,
    this.filmstripVisible = true,
    this.chromeVisible = true,
  });

  final bool engineReady;
  final String engineVersion;
  final String? rawPath;
  final Uint8List? previewPng;
  final int? imageWidth;
  final int? imageHeight;
  final PreviewStatus previewStatus;
  final PreviewZoomMode previewZoomMode;
  final String? errorMessage;
  final String? statusMessage;
  final int exportQuality;
  final StudioModule activeModule;
  final bool leftPanelVisible;
  final bool rightPanelVisible;
  final bool filmstripVisible;
  final bool chromeVisible;

  String? get fileName => rawPath == null ? null : p.basename(rawPath!);

  StudioState copyWith({
    bool? engineReady,
    String? engineVersion,
    String? rawPath,
    Uint8List? previewPng,
    bool clearPreview = false,
    int? imageWidth,
    int? imageHeight,
    PreviewStatus? previewStatus,
    PreviewZoomMode? previewZoomMode,
    String? errorMessage,
    bool clearError = false,
    String? statusMessage,
    int? exportQuality,
    StudioModule? activeModule,
    bool? leftPanelVisible,
    bool? rightPanelVisible,
    bool? filmstripVisible,
    bool? chromeVisible,
  }) {
    return StudioState(
      engineReady: engineReady ?? this.engineReady,
      engineVersion: engineVersion ?? this.engineVersion,
      rawPath: rawPath ?? this.rawPath,
      previewPng: clearPreview ? null : previewPng ?? this.previewPng,
      imageWidth: clearPreview ? null : imageWidth ?? this.imageWidth,
      imageHeight: clearPreview ? null : imageHeight ?? this.imageHeight,
      previewStatus: previewStatus ?? this.previewStatus,
      previewZoomMode: previewZoomMode ?? this.previewZoomMode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      exportQuality: exportQuality ?? this.exportQuality,
      activeModule: activeModule ?? this.activeModule,
      leftPanelVisible: leftPanelVisible ?? this.leftPanelVisible,
      rightPanelVisible: rightPanelVisible ?? this.rightPanelVisible,
      filmstripVisible: filmstripVisible ?? this.filmstripVisible,
      chromeVisible: chromeVisible ?? this.chromeVisible,
    );
  }
}

StudioLayoutMode layoutModeForWidth(double viewportWidth) {
  if (viewportWidth >= StudioLayoutBreakpoints.sidePanelsMin) {
    return StudioLayoutMode.wide;
  }
  if (viewportWidth > StudioLayoutBreakpoints.compactMax) {
    return StudioLayoutMode.medium;
  }
  return StudioLayoutMode.compact;
}
