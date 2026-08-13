import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nixin_studio_v8/studio/studio_state.dart';

void main() {
  group('layoutModeForWidth', () {
    test('selects wide composition when side panels have room', () {
      expect(layoutModeForWidth(1440), StudioLayoutMode.wide);
      expect(
        layoutModeForWidth(StudioLayoutBreakpoints.sidePanelsMin),
        StudioLayoutMode.wide,
      );
    });

    test('selects medium composition for tablet and narrow desktop widths', () {
      expect(layoutModeForWidth(1099), StudioLayoutMode.medium);
      expect(layoutModeForWidth(800), StudioLayoutMode.medium);
    });

    test('selects compact composition below 800 pixels', () {
      expect(layoutModeForWidth(799), StudioLayoutMode.compact);
      expect(layoutModeForWidth(480), StudioLayoutMode.compact);
    });
  });

  group('StudioState', () {
    test('derives the selected file name from path', () {
      const state = StudioState(rawPath: '/photos/session/image.nef');
      expect(state.fileName, 'image.nef');
    });

    test('defaults preview to fit with filmstrip and chrome visible', () {
      const state = StudioState();
      expect(state.previewZoomMode, PreviewZoomMode.fit);
      expect(state.filmstripVisible, isTrue);
      expect(state.chromeVisible, isTrue);
    });

    test('copyWith updates preview zoom, filmstrip, and chrome visibility', () {
      const state = StudioState();
      final next = state.copyWith(
        previewZoomMode: PreviewZoomMode.oneToOne,
        filmstripVisible: false,
        chromeVisible: false,
      );

      expect(next.previewZoomMode, PreviewZoomMode.oneToOne);
      expect(next.filmstripVisible, isFalse);
      expect(next.chromeVisible, isFalse);
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
