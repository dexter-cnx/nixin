import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/studio/studio_state.dart';

void main() {
  group('layoutModeForRatio', () {
    test('selects wide composition at wide ratio', () {
      expect(layoutModeForRatio(1.8), StudioLayoutMode.wide);
      expect(
        layoutModeForRatio(StudioLayoutRatios.wideMinAspect),
        StudioLayoutMode.wide,
      );
    });

    test('selects medium composition between ratio thresholds', () {
      expect(layoutModeForRatio(1.4), StudioLayoutMode.medium);
      expect(
        layoutModeForRatio(StudioLayoutRatios.mediumMinAspect),
        StudioLayoutMode.medium,
      );
    });

    test('selects compact composition below medium ratio', () {
      expect(layoutModeForRatio(1.0), StudioLayoutMode.compact);
    });
  });

  group('StudioState', () {
    test('derives the selected file name from path', () {
      const state = StudioState(rawPath: '/photos/session/image.nef');
      expect(state.fileName, 'image.nef');
    });

    test('defaults preview to fit and keeps filmstrip visible', () {
      const state = StudioState();
      expect(state.previewZoomMode, PreviewZoomMode.fit);
      expect(state.filmstripVisible, isTrue);
    });

    test('copyWith updates preview zoom and filmstrip visibility', () {
      const state = StudioState();
      final next = state.copyWith(
        previewZoomMode: PreviewZoomMode.oneToOne,
        filmstripVisible: false,
      );

      expect(next.previewZoomMode, PreviewZoomMode.oneToOne);
      expect(next.filmstripVisible, isFalse);
    });

    test('clearPreview clears preview bytes and dimensions', () {
      final state = StudioState(
        previewPng: Uint8List.fromList(const [1, 2, 3]),
        imageWidth: 320,
        imageHeight: 200,
        previewStatus: PreviewStatus.ready,
      );

      final next = state.copyWith(
        clearPreview: true,
        previewStatus: PreviewStatus.empty,
      );

      expect(next.previewPng, isNull);
      expect(next.imageWidth, isNull);
      expect(next.imageHeight, isNull);
      expect(next.previewStatus, PreviewStatus.empty);
    });

    test('clearError removes the previous error', () {
      const state = StudioState(errorMessage: 'boom');
      final next = state.copyWith(clearError: true);
      expect(next.errorMessage, isNull);
    });
  });
}
