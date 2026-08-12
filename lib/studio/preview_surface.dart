import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app/theme/studio_theme.dart';
import 'studio_state.dart';

class StudioPreviewSurface extends StatelessWidget {
  const StudioPreviewSurface({
    super.key,
    required this.state,
    required this.onZoomModeChanged,
  });

  final StudioState state;
  final ValueChanged<PreviewZoomMode> onZoomModeChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudioColors.workspace,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _previewContent(context)),
          if (state.previewPng != null)
            Positioned(
              right: StudioSpacing.md,
              bottom: StudioSpacing.md,
              child: _PreviewToolbar(
                mode: state.previewZoomMode,
                onChanged: onZoomModeChanged,
              ),
            ),
          if (state.previewStatus == PreviewStatus.processing)
            Container(
              color: Colors.black38,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: StudioSpacing.md),
                  Text('preview.processing'.tr()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewContent(BuildContext context) {
    if (state.previewStatus == PreviewStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(StudioSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: StudioColors.error,
                size: 36,
              ),
              const SizedBox(height: StudioSpacing.md),
              Text('preview.error'.tr()),
              const SizedBox(height: StudioSpacing.sm),
              Text(
                state.errorMessage ?? '',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final bytes = state.previewPng;
    if (bytes != null) {
      if (state.previewZoomMode == PreviewZoomMode.oneToOne) {
        return InteractiveViewer(
          minScale: 0.25,
          maxScale: 8,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(StudioSpacing.xl),
          child: SizedBox(
            width: state.imageWidth?.toDouble(),
            height: state.imageHeight?.toDouble(),
            child: Image.memory(bytes, fit: BoxFit.none, gaplessPlayback: true),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(StudioSpacing.lg),
        child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_size_select_actual_outlined, size: 44),
          const SizedBox(height: StudioSpacing.md),
          Text(
            'preview.empty_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            'preview.empty_body'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PreviewToolbar extends StatelessWidget {
  const _PreviewToolbar({required this.mode, required this.onChanged});

  final PreviewZoomMode mode;
  final ValueChanged<PreviewZoomMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.surface,
      borderRadius: BorderRadius.circular(StudioRadius.sm),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.xxs),
        child: SegmentedButton<PreviewZoomMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: PreviewZoomMode.fit,
              label: Text('preview.fit'.tr()),
            ),
            ButtonSegment(
              value: PreviewZoomMode.oneToOne,
              label: Text('preview.one_to_one'.tr()),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ),
    );
  }
}
