import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/studio_theme.dart';
import '../workplaces/application/import_controller.dart';
import '../workplaces/application/import_state.dart';
import '../workplaces/application/workplace_controller.dart';
import '../workplaces/domain/asset_record.dart';
import 'studio_controller.dart';
import 'studio_widgets.dart';

enum StudioImportControlMode { panel, floating, compact }

enum _ImportMenu {
  folder,
  folderCurrentOnly,
  linked,
  managed,
  cancel,
}

enum _WorkplaceMenu { create, rename, delete }

class StudioImportControls extends ConsumerWidget {
  const StudioImportControls({
    super.key,
    this.mode = StudioImportControlMode.panel,
  });

  final StudioImportControlMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workplaceState = ref.watch(workplaceControllerProvider);
    final importState = ref.watch(importControllerProvider);
    final workplaceController = ref.read(workplaceControllerProvider.notifier);

    if (mode == StudioImportControlMode.floating) {
      return _FloatingImport(
        busy: importState.busy,
        onImport: () => _importFiles(ref),
        onMenu: (value) => _handleMenu(ref, value),
      );
    }

    if (mode == StudioImportControlMode.compact) {
      return Row(
        children: [
          Expanded(
            child: ActionButton(
              icon: Icons.add_photo_alternate_outlined,
              label: 'action.import'.tr(),
              onPressed: importState.busy ? null : () => _importFiles(ref),
              primary: true,
            ),
          ),
          const SizedBox(width: StudioSpacing.xs),
          _ImportMenuButton(
            state: importState,
            onSelected: (value) => _handleMenu(ref, value),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: workplaceState.currentWorkplaceId,
                  hint: Text(
                    workplaceState.loading
                        ? 'workplace.loading'.tr()
                        : 'workplace.title'.tr(),
                  ),
                  items: workplaceState.workplaces
                      .map(
                        (workplace) => DropdownMenuItem(
                          value: workplace.id,
                          child: Text(
                            workplace.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: workplaceState.loading
                      ? null
                      : (id) {
                          if (id != null) {
                            workplaceController.switchWorkplace(id);
                          }
                        },
                ),
              ),
            ),
            PopupMenuButton<_WorkplaceMenu>(
              tooltip: 'workplace.title'.tr(),
              onSelected: (value) => _handleWorkplaceMenu(
                context,
                workplaceController,
                workplaceState,
                value,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _WorkplaceMenu.create,
                  child: Text('workplace.create'.tr()),
                ),
                PopupMenuItem(
                  value: _WorkplaceMenu.rename,
                  enabled: workplaceState.currentWorkplace != null,
                  child: Text('workplace.rename'.tr()),
                ),
                PopupMenuItem(
                  value: _WorkplaceMenu.delete,
                  enabled: workplaceState.workplaces.length > 1,
                  child: Text('workplace.delete'.tr()),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: StudioSpacing.sm),
        Row(
          children: [
            Expanded(
              child: ActionButton(
                icon: Icons.add_photo_alternate_outlined,
                label: 'action.import'.tr(),
                onPressed: importState.busy ? null : () => _importFiles(ref),
                primary: true,
              ),
            ),
            const SizedBox(width: StudioSpacing.xs),
            _ImportMenuButton(
              state: importState,
              onSelected: (value) => _handleMenu(ref, value),
            ),
          ],
        ),
        if (importState.busy ||
            importState.phase == ImportPhase.completed ||
            importState.phase == ImportPhase.cancelled) ...[
          const SizedBox(height: StudioSpacing.sm),
          if (importState.busy)
            LinearProgressIndicator(value: importState.progress),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            _statusText(importState),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  static Future<void> _importFiles(WidgetRef ref) async {
    final controller = ref.read(importControllerProvider.notifier);
    await controller.importFiles();
    await _openLastImported(ref);
  }

  static Future<void> _openLastImported(WidgetRef ref) async {
    final path = ref.read(importControllerProvider).lastImportedPath;
    if (path == null) return;
    final studio = ref.read(studioControllerProvider.notifier);
    studio.selectRawPath(path);
    await studio.develop();
  }

  static Future<void> _handleMenu(WidgetRef ref, _ImportMenu value) async {
    final controller = ref.read(importControllerProvider.notifier);
    switch (value) {
      case _ImportMenu.folder:
        await controller.importFolder();
        await _openLastImported(ref);
        return;
      case _ImportMenu.folderCurrentOnly:
        await controller.importFolder(recursive: false);
        await _openLastImported(ref);
        return;
      case _ImportMenu.linked:
        await controller.setStorageMode(AssetStorageMode.linked);
        return;
      case _ImportMenu.managed:
        await controller.setStorageMode(AssetStorageMode.managed);
        return;
      case _ImportMenu.cancel:
        controller.cancel();
        return;
    }
  }

  static Future<void> _handleWorkplaceMenu(
    BuildContext context,
    WorkplaceController controller,
    WorkplaceState state,
    _WorkplaceMenu value,
  ) async {
    switch (value) {
      case _WorkplaceMenu.create:
        final name = await _askName(context, 'workplace.create'.tr(), '');
        if (name != null) {
          final workplace = await controller.createWorkplace(name);
          await controller.switchWorkplace(workplace.id);
        }
        return;
      case _WorkplaceMenu.rename:
        final current = state.currentWorkplace;
        if (current == null) return;
        final name = await _askName(
          context,
          'workplace.rename'.tr(),
          current.name,
        );
        if (name != null) {
          await controller.renameWorkplace(current.id, name);
        }
        return;
      case _WorkplaceMenu.delete:
        final current = state.currentWorkplace;
        if (current == null || state.workplaces.length <= 1) return;
        await controller.deleteWorkplace(current.id);
        return;
    }
  }

  static Future<String?> _askName(
    BuildContext context,
    String title,
    String initialValue,
  ) async {
    final textController = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text.trim()),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null || result.trim().isEmpty) return null;
    return result.trim();
  }

  static String _statusText(ImportState state) {
    if (state.phase == ImportPhase.cancelled) {
      return 'import.cancelled'.tr();
    }
    if (state.phase == ImportPhase.completed) {
      return 'import.summary'.tr(namedArgs: {
        'imported': '${state.imported}',
        'duplicates': '${state.skippedDuplicates}',
        'failed': '${state.failed}',
      });
    }
    return 'import.progress'.tr(namedArgs: {
      'processed': '${state.processed}',
      'total': '${state.total}',
      'file': state.currentFile ?? '',
    });
  }
}

class _ImportMenuButton extends StatelessWidget {
  const _ImportMenuButton({required this.state, required this.onSelected});

  final ImportState state;
  final ValueChanged<_ImportMenu> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ImportMenu>(
      tooltip: 'import.options'.tr(),
      icon: const Icon(Icons.arrow_drop_down),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ImportMenu.folder,
          enabled: !state.busy,
          child: Text('import.folder'.tr()),
        ),
        PopupMenuItem(
          value: _ImportMenu.folderCurrentOnly,
          enabled: !state.busy,
          child: Text('import.folder_no_subfolders'.tr()),
        ),
        const PopupMenuDivider(),
        CheckedPopupMenuItem(
          value: _ImportMenu.linked,
          checked: state.storageMode == AssetStorageMode.linked,
          enabled: !state.busy,
          child: Text('import.linked'.tr()),
        ),
        CheckedPopupMenuItem(
          value: _ImportMenu.managed,
          checked: state.storageMode == AssetStorageMode.managed,
          enabled: !state.busy,
          child: Text('import.managed'.tr()),
        ),
        if (state.busy) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _ImportMenu.cancel,
            child: Text('import.cancel'.tr()),
          ),
        ],
      ],
    );
  }
}

class _FloatingImport extends StatelessWidget {
  const _FloatingImport({
    required this.busy,
    required this.onImport,
    required this.onMenu,
  });

  final bool busy;
  final VoidCallback onImport;
  final ValueChanged<_ImportMenu> onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'action.import'.tr(),
          onPressed: busy ? null : onImport,
          icon: const Icon(Icons.add_photo_alternate_outlined),
        ),
        PopupMenuButton<_ImportMenu>(
          tooltip: 'import.options'.tr(),
          onSelected: onMenu,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _ImportMenu.folder,
              enabled: !busy,
              child: Text('import.folder'.tr()),
            ),
            PopupMenuItem(
              value: _ImportMenu.folderCurrentOnly,
              enabled: !busy,
              child: Text('import.folder_no_subfolders'.tr()),
            ),
          ],
        ),
      ],
    );
  }
}
