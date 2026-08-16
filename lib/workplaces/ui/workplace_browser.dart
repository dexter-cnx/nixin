import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
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
      color: StudioColors.workspace,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrowserToolbar(state: state, controller: controller),
          const Divider(height: 1, color: StudioColors.divider),
          Expanded(
            child: _BrowserBody(
              state: state,
              onRetry: controller.refresh,
              onAssetSelected: (asset) {
                if (asset.missing) return;
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
  const _BrowserToolbar({required this.state, required this.controller});

  final AssetBrowserState state;
  final AssetBrowserController controller;

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
          if (state.missingCount > 0) ...[
            const SizedBox(width: StudioSpacing.sm),
            Text(
              'workplace.missing_count'.tr(
                namedArgs: {'count': '${state.missingCount}'},
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: StudioColors.error),
            ),
          ],
          const Spacer(),
          IconButton(
            tooltip: 'workplace.scan_missing'.tr(),
            onPressed: state.scanningAvailability
                ? null
                : () => controller.scanAvailability(),
            icon: state.scanningAvailability
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync, size: 18),
          ),
          if (state.missingCount > 0)
            IconButton(
              tooltip: 'workplace.locate_folder'.tr(),
              onPressed: () => _locateMissingFolder(context, controller),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
            ),
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
                if (value != null) controller.setSortOrder(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _locateMissingFolder(
    BuildContext context,
    AssetBrowserController controller,
  ) async {
    final root = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'workplace.locate_folder'.tr(),
    );
    if (root == null) return;
    final count = await controller.relinkMissingFromFolder(root);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'workplace.relinked_count'.tr(namedArgs: {'count': '$count'}),
        ),
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
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32),
            const SizedBox(height: StudioSpacing.sm),
            Text('workplace.browser_error'.tr()),
            const SizedBox(height: StudioSpacing.sm),
            OutlinedButton(onPressed: onRetry, child: Text('workplace.retry'.tr())),
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
              size: 44,
              color: StudioColors.textSecondary,
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text('workplace.empty'.tr(), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              'workplace.empty_body'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          >= 1400 => 7,
          >= 1100 => 6,
          >= 900 => 5,
          >= 700 => 4,
          >= 520 => 3,
          _ => 2,
        };
        return GridView.builder(
          padding: const EdgeInsets.all(StudioSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: StudioSpacing.sm,
            mainAxisSpacing: StudioSpacing.sm,
            childAspectRatio: 1.08,
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

enum _AssetMenuAction { locate, remove }

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(StudioRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: StudioColors.surface,
            borderRadius: BorderRadius.circular(StudioRadius.md),
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
                    _AssetThumbnail(asset: asset),
                    if (asset.missing)
                      Positioned(
                        left: StudioSpacing.xs,
                        top: StudioSpacing.xs,
                        child: Tooltip(
                          message: 'workplace.missing'.tr(),
                          child: const Icon(
                            Icons.link_off,
                            size: 18,
                            color: StudioColors.error,
                          ),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: PopupMenuButton<_AssetMenuAction>(
                        tooltip: 'workplace.asset_options'.tr(),
                        onSelected: (action) => _handleAction(context, ref, action),
                        itemBuilder: (context) => [
                          if (asset.missing)
                            PopupMenuItem(
                              value: _AssetMenuAction.locate,
                              child: Text('workplace.locate_file'.tr()),
                            ),
                          PopupMenuItem(
                            value: _AssetMenuAction.remove,
                            child: Text('workplace.remove'.tr()),
                          ),
                        ],
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

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _AssetMenuAction action,
  ) async {
    final controller = ref.read(assetBrowserControllerProvider.notifier);
    switch (action) {
      case _AssetMenuAction.locate:
        final result = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          dialogTitle: 'workplace.locate_file'.tr(),
        );
        final path = result?.files.single.path;
        if (path == null) return;
        final ok = await controller.relinkAsset(asset.id, path);
        if (!context.mounted || ok) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('workplace.relink_failed'.tr())),
        );
      case _AssetMenuAction.remove:
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('workplace.remove'.tr()),
                content: Text('workplace.remove_body'.tr()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('workplace.remove'.tr()),
                  ),
                ],
              ),
            ) ??
            false;
        if (confirmed) await controller.removeFromWorkplace(asset.id);
    }
  }
}

class _AssetThumbnail extends ConsumerWidget {
  const _AssetThumbnail({required this.asset});

  final AssetRecord asset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(assetPreviewProvider).thumbnail(asset);
    return FutureBuilder<Uint8List?>(
      future: preview,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Icon(
              Icons.image_outlined,
              size: 30,
              color: StudioColors.textSecondary,
            ),
          );
        }
        return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      },
    );
  }
}
