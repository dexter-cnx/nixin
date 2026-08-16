import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/studio_theme.dart';
import '../workplaces/application/asset_browser_controller.dart';
import '../workplaces/application/asset_preview_provider.dart';
import '../workplaces/domain/asset_record.dart';
import 'studio_state.dart';

class StudioFilmstrip extends ConsumerWidget {
  const StudioFilmstrip({
    super.key,
    required this.state,
    required this.onToggleVisibility,
    required this.onAssetSelected,
  });

  final StudioState state;
  final VoidCallback onToggleVisibility;
  final ValueChanged<AssetRecord> onAssetSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final browserState = ref.watch(assetBrowserControllerProvider);
    final browserController = ref.read(assetBrowserControllerProvider.notifier);

    if (!state.filmstripVisible) {
      return _FilmstripHeader(
        expanded: false,
        count: browserState.assets.length,
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
            count: browserState.assets.length,
            onToggleVisibility: onToggleVisibility,
          ),
          Expanded(
            child: browserState.loading
                ? const Center(child: CircularProgressIndicator())
                : browserState.assets.isEmpty
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
                        itemCount: browserState.assets.length,
                        itemBuilder: (context, index) {
                          final asset = browserState.assets[index];
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: StudioSpacing.xs,
                            ),
                            child: _FilmstripItem(
                              asset: asset,
                              selected:
                                  asset.id == browserState.selectedAssetId,
                              onTap: () {
                                browserController.select(asset.id);
                                onAssetSelected(asset);
                              },
                            ),
                          );
                        },
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
    required this.count,
    required this.onToggleVisibility,
  });

  final bool expanded;
  final int count;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StudioMetrics.filmstripCollapsedHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.sm),
        child: Row(
          children: [
            Text(
              '${'filmstrip.title'.tr()} · $count',
              style: Theme.of(context).textTheme.labelMedium,
            ),
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

class _FilmstripItem extends ConsumerWidget {
  const _FilmstripItem({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final AssetRecord asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewProvider = ref.watch(assetPreviewProvider);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioRadius.sm),
        child: Container(
          width: StudioMetrics.filmstripItemWidth,
          decoration: BoxDecoration(
            color: StudioColors.surface,
            borderRadius: BorderRadius.circular(StudioRadius.sm),
            border: Border.all(
              color: selected ? StudioColors.accent : StudioColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: previewProvider.thumbnail(asset),
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes == null) {
                          return const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: StudioColors.textSecondary,
                            ),
                          );
                        }
                        return Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        );
                      },
                    ),
                    if (asset.missing)
                      const Positioned(
                        right: StudioSpacing.xs,
                        top: StudioSpacing.xs,
                        child: Icon(
                          Icons.link_off,
                          size: 16,
                          color: StudioColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: StudioColors.surfaceHigh,
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.xs,
                  vertical: StudioSpacing.xxs,
                ),
                child: Text(
                  asset.originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
