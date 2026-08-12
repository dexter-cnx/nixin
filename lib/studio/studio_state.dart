import 'dart:typed_data';

import 'package:path/path.dart' as p;

enum StudioModule { library, develop, export }

enum PreviewStatus { empty, processing, ready, error }

enum StudioLayoutMode { wide, medium, compact }

abstract final class StudioLayoutRatios {
  static const wideMinAspect = 1.65;
  static const mediumMinAspect = 1.15;
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
    this.errorMessage,
    this.statusMessage,
    this.exportQuality = 90,
    this.activeModule = StudioModule.develop,
    this.leftPanelVisible = true,
    this.rightPanelVisible = true,
  });

  final bool engineReady;
  final String engineVersion;
  final String? rawPath;
  final Uint8List? previewPng;
  final int? imageWidth;
  final int? imageHeight;
  final PreviewStatus previewStatus;
  final String? errorMessage;
  final String? statusMessage;
  final int exportQuality;
  final StudioModule activeModule;
  final bool leftPanelVisible;
  final bool rightPanelVisible;

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
    String? errorMessage,
    bool clearError = false,
    String? statusMessage,
    int? exportQuality,
    StudioModule? activeModule,
    bool? leftPanelVisible,
    bool? rightPanelVisible,
  }) {
    return StudioState(
      engineReady: engineReady ?? this.engineReady,
      engineVersion: engineVersion ?? this.engineVersion,
      rawPath: rawPath ?? this.rawPath,
      previewPng: clearPreview ? null : previewPng ?? this.previewPng,
      imageWidth: clearPreview ? null : imageWidth ?? this.imageWidth,
      imageHeight: clearPreview ? null : imageHeight ?? this.imageHeight,
      previewStatus: previewStatus ?? this.previewStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      exportQuality: exportQuality ?? this.exportQuality,
      activeModule: activeModule ?? this.activeModule,
      leftPanelVisible: leftPanelVisible ?? this.leftPanelVisible,
      rightPanelVisible: rightPanelVisible ?? this.rightPanelVisible,
    );
  }
}

StudioLayoutMode layoutModeForRatio(double viewportRatio) {
  if (viewportRatio >= StudioLayoutRatios.wideMinAspect) {
    return StudioLayoutMode.wide;
  }
  if (viewportRatio >= StudioLayoutRatios.mediumMinAspect) {
    return StudioLayoutMode.medium;
  }
  return StudioLayoutMode.compact;
}
