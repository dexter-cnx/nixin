import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/studio_theme.dart';
import 'editor_controls.dart';
import 'filmstrip.dart';
import 'preview_surface.dart';
import 'studio_controller.dart';
import 'studio_state.dart';
import 'studio_widgets.dart';

class StudioPage extends ConsumerWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studioControllerProvider);
    final controller = ref.read(studioControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.tab): () {
              controller.toggleSidePanels();
            },
            const SingleActivator(LogicalKeyboardKey.tab, shift: true): () {
              controller.toggleChrome();
            },
          },
          child: Focus(
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final mode = layoutModeForWidth(constraints.maxWidth);
                return Column(
                  children: [
                    if (state.chromeVisible)
                      StudioModuleBar(
                        activeModule: state.activeModule,
                        onModuleSelected: controller.setModule,
                        onToggleLeft: controller.toggleLeftPanel,
                        onToggleRight: controller.toggleRightPanel,
                        showPanelToggles: mode == StudioLayoutMode.wide,
                        compact: mode == StudioLayoutMode.compact,
                      ),
                    Expanded(
                      child: switch (mode) {
                        StudioLayoutMode.wide => _WideWorkspace(
                            state: state,
                            controller: controller,
                          ),
                        StudioLayoutMode.medium => _MediumWorkspace(
                            state: state,
                            controller: controller,
                          ),
                        StudioLayoutMode.compact => _CompactWorkspace(
                            state: state,
                            controller: controller,
                          ),
                      },
                    ),
                    if (state.chromeVisible && mode != StudioLayoutMode.compact)
                      StudioFilmstrip(
                        state: state,
                        onToggleVisibility: controller.toggleFilmstrip,
                        onSelectCurrent: controller.develop,
                      ),
                    if (state.chromeVisible && mode != StudioLayoutMode.compact)
                      StudioStatusBar(state: state),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WideWorkspace extends StatelessWidget {
  const _WideWorkspace({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (state.leftPanelVisible)
          Expanded(
            flex: StudioLayoutRatios.wideLeft,
            child: _LeftPanel(state: state, controller: controller),
          ),
        Expanded(
          flex: StudioLayoutRatios.wideCenter,
          child: StudioPreviewSurface(
            state: state,
            onZoomModeChanged: controller.setPreviewZoomMode,
          ),
        ),
        if (state.rightPanelVisible)
          Expanded(
            flex: StudioLayoutRatios.wideRight,
            child: _RightPanel(state: state, controller: controller),
          ),
      ],
    );
  }
}

class _MediumWorkspace extends StatelessWidget {
  const _MediumWorkspace({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: StudioLayoutRatios.mediumCenter,
              child: StudioPreviewSurface(
                state: state,
                onZoomModeChanged: controller.setPreviewZoomMode,
              ),
            ),
            if (state.rightPanelVisible)
              Expanded(
                flex: StudioLayoutRatios.mediumRight,
                child: _RightPanel(state: state, controller: controller),
              ),
          ],
        ),
        Positioned(
          left: StudioSpacing.sm,
          top: StudioSpacing.sm,
          child: Column(
            children: [
              IconButton.filledTonal(
                tooltip: 'action.open_raw'.tr(),
                onPressed: controller.pickRaw,
                icon: const Icon(Icons.folder_open),
              ),
              const SizedBox(height: StudioSpacing.xs),
              IconButton.filledTonal(
                tooltip: 'panel.tools'.tr(),
                onPressed: controller.toggleRightPanel,
                icon: Icon(
                  state.rightPanelVisible
                      ? Icons.chevron_right
                      : Icons.chevron_left,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactWorkspace extends StatelessWidget {
  const _CompactWorkspace({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StudioPreviewSurface(
            state: state,
            onZoomModeChanged: controller.setPreviewZoomMode,
          ),
        ),
        Container(
          color: StudioColors.panel,
          padding: const EdgeInsets.all(StudioSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: ActionButton(
                  icon: Icons.folder_open,
                  label: 'action.open_raw'.tr(),
                  onPressed: controller.pickRaw,
                  primary: true,
                ),
              ),
              const SizedBox(width: StudioSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'panel.tools'.tr(),
                onPressed: () => _showTools(context),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showTools(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: StudioColors.panel,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.72,
        child: _RightPanel(state: state, controller: controller),
      ),
    );
  }
}

class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    return StudioPanel(
      trailingBorder: true,
      children: [
        StudioPanelSection(
          title: 'panel.navigator'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ActionButton(
                icon: Icons.folder_open,
                label: 'action.open_raw'.tr(),
                onPressed: controller.pickRaw,
                primary: true,
              ),
              if (state.fileName != null) ...[
                const SizedBox(height: StudioSpacing.sm),
                Text(
                  state.fileName!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        StudioPanelSection(
          title: 'panel.presets'.tr(),
          child: ActionButton(
            icon: Icons.auto_fix_high_outlined,
            label: 'action.apply_lut'.tr(),
            onPressed: state.rawPath == null ? null : controller.applyLut,
          ),
        ),
      ],
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.state, required this.controller});

  final StudioState state;
  final StudioController controller;

  @override
  Widget build(BuildContext context) {
    final enabled = state.rawPath != null && state.engineReady;
    return StudioPanel(
      children: [
        StudioPanelSection(
          title: 'panel.tools'.tr(),
          child: Column(
            children: [
              ActionButton(
                icon: Icons.developer_board_outlined,
                label: 'action.develop'.tr(),
                onPressed: enabled ? controller.develop : null,
                primary: true,
              ),
              const SizedBox(height: StudioSpacing.sm),
              ActionButton(
                icon: Icons.center_focus_strong,
                label: 'action.subject_mask'.tr(),
                onPressed: enabled ? controller.subjectMask : null,
              ),
              const SizedBox(height: StudioSpacing.sm),
              ActionButton(
                icon: Icons.cloud_outlined,
                label: 'action.sky_mask'.tr(),
                onPressed: enabled ? controller.skyMask : null,
              ),
            ],
          ),
        ),
        StudioPanelSection(
          title: 'panel.export'.tr(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ParameterSlider(
                label: 'settings.jpeg_quality'.tr(),
                value: state.exportQuality.toDouble(),
                min: 1,
                max: 100,
                divisions: 99,
                onChanged: (value) =>
                    controller.setExportQuality(value.round()),
              ),
              const SizedBox(height: StudioSpacing.sm),
              ActionButton(
                icon: Icons.ios_share_outlined,
                label: 'action.export_jpeg'.tr(),
                onPressed: enabled ? controller.exportJpeg : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
