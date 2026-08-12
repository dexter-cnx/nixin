import 'dart:typed_data';

import 'package:path/path.dart' as p;

enum StudioModule { library, develop, export }

enum PreviewStatus { empty, processing, ready, error }

enum StudioLayoutMode { wide, medium, compact }

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
      previewPng: previewPng ?? this.previewPng,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
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
  if (viewportRatio >= 1.65) return StudioLayoutMode.wide;
  if (viewportRatio >= 1.15) return StudioLayoutMode.medium;
  return StudioLayoutMode.compact;
}
