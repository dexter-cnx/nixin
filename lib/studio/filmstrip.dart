import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../app/theme/studio_theme.dart';
import 'studio_state.dart';

class StudioFilmstrip extends StatelessWidget {
  const StudioFilmstrip({
    super.key,
    required this.state,
    required this.onToggleVisibility,
  });

  final StudioState state;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    if (!state.filmstripVisible) {
      return _FilmstripHeader(
        expanded: false,
        onToggleVisibility: onToggleVisibility,
      );
    }

    return Container(
      height: StudioMetrics.filmstripHeight,
      decoration: const BoxDecoration(
        color: StudioColors.panel,
        border: Border(top: BorderSide(color: StudioColors.divider)),
      ),
      child: Column(
        children: [
          _FilmstripHeader(
            expanded: true,
            onToggleVisibility: onToggleVisibility,
          ),
          Expanded(
            child: state.rawPath == null
                ? Center(
                    child: Text(
                      'filmstrip.empty'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(
                      StudioSpacing.sm,
                      StudioSpacing.xs,
                      StudioSpacing.sm,
                      StudioSpacing.sm,
                    ),
                    itemCount: 1,
                    itemBuilder: (context, index) => _FilmstripItem(state: state),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilmstripHeader extends StatelessWidget {
  const _FilmstripHeader({
    required this.expanded,
    required this.onToggleVisibility,
  });

  final bool expanded;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StudioMetrics.filmstripCollapsedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm),
        child: Row(
          children: [
            Text('filmstrip.title'.tr(), style: Theme.of(context).textTheme.labelMedium),
            const Spacer(),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: expanded ? 'filmstrip.hide'.tr() : 'filmstrip.show'.tr(),
              onPressed: onToggleVisibility,
              icon: Icon(
                expanded ? Icons.expand_more : Icons.expand_less,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilmstripItem extends StatelessWidget {
  const _FilmstripItem({required this.state});

  final StudioState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: StudioMetrics.filmstripItemWidth,
      decoration: BoxDecoration(
        color: StudioColors.surface,
        borderRadius: BorderRadius.circular(StudioRadius.sm),
        border: Border.all(color: StudioColors.accent),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: state.previewPng == null
                ? const Center(
                    child: Icon(Icons.image_outlined, color: StudioColors.textSecondary),
                  )
                : Image.memory(
                    state.previewPng!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
          Container(
            color: StudioColors.surfaceHigh,
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.xs,
              vertical: StudioSpacing.xxs,
            ),
            child: Text(
              state.fileName ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
