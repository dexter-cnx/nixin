import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/studio_theme.dart';
import '../application/asset_browser_controller.dart';
import '../application/asset_preview_provider.dart';
import '../domain/asset_record.dart';

class WorkplaceBrowser extends ConsumerWidget {
  const WorkplaceBrowser({
    super.key,
    required this.onAssetSelected,
  });

  final ValueChanged<AssetRecord> onAssetSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assetBrowserControllerProvider);
    final controller = ref.read(assetBrowserControllerProvider.notifier);

    return Container(
      color: StudioColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrowserToolbar(
            state: state,
            onSortChanged: controller.setSortOrder,
          ),
          const Divider(height: 1, color: StudioColors.divider),
          Expanded(
            child: _BrowserBody(
              state: state,
              onRetry: controller.refresh,
              onAssetSelected: (asset) {
                controller.select(asset.id);
                onAssetSelected(asset);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserToolbar extends StatelessWidget {
  const _BrowserToolbar({required this.state, required this.onSortChanged});

  final AssetBrowserState state;
  final ValueChanged<AssetSortOrder> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.md,
        vertical: StudioSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '${state.assets.length} ${'workplace.assets'.tr()}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<AssetSortOrder>(
              value: state.sortOrder,
              items: [
                DropdownMenuItem(
                  value: AssetSortOrder.importedAscending,
                  child: Text('workplace.sort_imported'.tr()),
                ),
                DropdownMenuItem(
                  value: AssetSortOrder.importedDescending,
                  child: Text('workplace.sort_recent'.tr()),
                ),
                DropdownMenuItem(
                  value: AssetSortOrder.nameAscending,
                  child: Text('workplace.sort_name'.tr()),
                ),
              ],
              onChanged: (value) {
                if (value != null) onSortChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowserBody extends StatelessWidget {
  const _BrowserBody({
    required this.state,
    required this.onRetry,
    required this.onAssetSelected,
  });

  final AssetBrowserState state;
  final VoidCallback onRetry;
  final ValueChanged<AssetRecord> onAssetSelected;

  @override
  Widget build(BuildContext context) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: StudioSpacing.sm),
            Text('workplace.browser_error'.tr()),
            const SizedBox(height: StudioSpacing.sm),
            OutlinedButton(
              onPressed: onRetry,
              child: Text('workplace.retry'.tr()),
            ),
          ],
        ),
      );
    }
    if (state.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 42,
              color: StudioColors.textSecondary,
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              'workplace.empty_assets'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              'workplace.empty_assets_hint'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1400
            ? 7
            : width >= 1100
                ? 6
                : width >= 800
                    ? 4
                    : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(StudioSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: StudioSpacing.sm,
            mainAxisSpacing: StudioSpacing.sm,
            childAspectRatio: 1.05,
          ),
          itemCount: state.assets.length,
          itemBuilder: (context, index) {
            final asset = state.assets[index];
            return _AssetTile(
              asset: asset,
              selected: asset.id == state.selectedAssetId,
              onTap: () => onAssetSelected(asset),
            );
          },
        );
      },
    );
  }
}

class _AssetTile extends ConsumerWidget {
  const _AssetTile({
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
      color: StudioColors.surface,
      borderRadius: BorderRadius.circular(StudioRadius.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StudioRadius.sm),
            border: Border.all(
              color: selected ? StudioColors.accent : StudioColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
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
                              size: 34,
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
                        top: StudioSpacing.xs,
                        right: StudioSpacing.xs,
                        child: Icon(
                          Icons.link_off,
                          size: 18,
                          color: StudioColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                color: StudioColors.surfaceHigh,
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.sm,
                  vertical: StudioSpacing.xs,
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
