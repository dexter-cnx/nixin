import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app/theme/studio_theme.dart';
import 'studio_state.dart';

class StudioModuleBar extends StatelessWidget {
  const StudioModuleBar({
    super.key,
    required this.activeModule,
    required this.onModuleSelected,
    required this.onToggleLeft,
    required this.onToggleRight,
    required this.showPanelToggles,
  });

  final StudioModule activeModule;
  final ValueChanged<StudioModule> onModuleSelected;
  final VoidCallback onToggleLeft;
  final VoidCallback onToggleRight;
  final bool showPanelToggles;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: StudioMetrics.moduleBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
      decoration: const BoxDecoration(
        color: StudioColors.panel,
        border: Border(bottom: BorderSide(color: StudioColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_mosaic_outlined, size: 20),
          const SizedBox(width: StudioSpacing.sm),
          Text('app_name'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          for (final module in StudioModule.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs),
              child: _ModuleButton(
                label: 'module.${module.name}'.tr(),
                selected: module == activeModule,
                onPressed: () => onModuleSelected(module),
              ),
            ),
          const Spacer(),
          if (showPanelToggles) ...[
            IconButton(
              tooltip: 'panel.navigator'.tr(),
              onPressed: onToggleLeft,
              icon: const Icon(Icons.left_panel_open_outlined, size: 20),
            ),
            IconButton(
              tooltip: 'panel.tools'.tr(),
              onPressed: onToggleRight,
              icon: const Icon(Icons.right_panel_open_outlined, size: 20),
            ),
          ],
        ],
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? StudioColors.textPrimary
            : StudioColors.textSecondary,
        backgroundColor: selected ? StudioColors.surfaceHigh : Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.md,
          vertical: StudioSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(StudioRadius.md),
        ),
      ),
      child: Text(label),
    );
  }
}

class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.children, this.trailingBorder = false});

  final List<Widget> children;
  final bool trailingBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: StudioColors.panel,
      decoration: BoxDecoration(
        border: Border(
          right: trailingBorder
              ? const BorderSide(color: StudioColors.divider)
              : BorderSide.none,
          left: !trailingBorder
              ? const BorderSide(color: StudioColors.divider)
              : BorderSide.none,
        ),
      ),
      child: ListView(padding: EdgeInsets.zero, children: children),
    );
  }
}

class StudioPanelSection extends StatefulWidget {
  const StudioPanelSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<StudioPanelSection> createState() => _StudioPanelSectionState();
}

class _StudioPanelSectionState extends State<StudioPanelSection> {
  late bool expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: StudioColors.divider)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.md,
                vertical: StudioSpacing.sm,
              ),
              child: Row(
                children: [
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 160),
                    turns: expanded ? 0.25 : 0,
                    child: const Icon(Icons.chevron_right, size: 18),
                  ),
                  const SizedBox(width: StudioSpacing.xs),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState: expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                StudioSpacing.md,
                0,
                StudioSpacing.md,
                StudioSpacing.md,
              ),
              child: widget.child,
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class PreviewWorkspace extends StatelessWidget {
  const PreviewWorkspace({super.key, required this.state});

  final StudioState state;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: StudioColors.workspace,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: _previewContent(context)),
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
      return Padding(
        padding: const EdgeInsets.all(StudioSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: StudioColors.error, size: 36),
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
      );
    }
    if (state.previewPng != null) {
      return Padding(
        padding: const EdgeInsets.all(StudioSpacing.lg),
        child: Image.memory(state.previewPng!, fit: BoxFit.contain, gaplessPlayback: true),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.photo_size_select_actual_outlined, size: 44),
        const SizedBox(height: StudioSpacing.md),
        Text('preview.empty_title'.tr(), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: StudioSpacing.xs),
        Text('preview.empty_body'.tr(), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class StudioStatusBar extends StatelessWidget {
  const StudioStatusBar({super.key, required this.state});

  final StudioState state;

  @override
  Widget build(BuildContext context) {
    final dimensions = state.imageWidth == null
        ? '—'
        : '${state.imageWidth} × ${state.imageHeight}';
    final statusKey = state.statusMessage == null
        ? 'status.ready'
        : 'status.${state.statusMessage}';
    return Container(
      height: StudioMetrics.statusBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
      decoration: const BoxDecoration(
        color: StudioColors.panel,
        border: Border(top: BorderSide(color: StudioColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(state.fileName ?? 'label.no_file'.tr(), overflow: TextOverflow.ellipsis)),
          Text(dimensions, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: StudioSpacing.lg),
          Text(
            state.engineReady
                ? '${'label.engine'.tr()} ${state.engineVersion}'
                : 'status.engine_unavailable'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: StudioSpacing.lg),
          Text(statusKey.tr(), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: StudioSpacing.sm),
        Flexible(child: Text(label)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}
