part of "page.dart";

class WorkspaceTileStyleTile extends ConsumerWidget {
  const WorkspaceTileStyleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile<WorkspaceTileStyle>(
    icon: Icons.dashboard_outlined,
    title: Text(context.l10n.appSettingsPageWorkspaceTileStyleTitle),
    subtitle: Text(context.l10n.appSettingsPageWorkspaceTileStyleDescription),
    initialValue: ref.watch(appSettingServiceProvider.select((s) => s.workspaceTileStyle)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(workspaceTileStyle: value)),
    items: [
      DropdownMenuItem(
        value: WorkspaceTileStyle.automatic,
        child: Text(context.l10n.appSettingsPageWorkspaceTileStyleAutomatic),
      ),
      DropdownMenuItem(
        value: WorkspaceTileStyle.square,
        child: Text(context.l10n.appSettingsPageWorkspaceTileStyleSquare),
      ),
      DropdownMenuItem(
        value: WorkspaceTileStyle.compact,
        child: Text(context.l10n.appSettingsPageWorkspaceTileStyleCompact),
      ),
    ],
  );
}

class WorkspaceColumnModeTile extends ConsumerWidget {
  const WorkspaceColumnModeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DropdownListTile<WorkspaceColumnMode>(
    icon: Icons.view_column_outlined,
    title: Text(context.l10n.appSettingsPageWorkspaceColumnModeTitle),
    subtitle: Text(context.l10n.appSettingsPageWorkspaceColumnModeDescription),
    initialValue: ref.watch(appSettingServiceProvider.select((s) => s.workspaceColumnMode)),
    onValueChange: (value) => ref
        .read(appSettingServiceProvider.notifier)
        .update((old) => old.copyWith(workspaceColumnMode: value)),
    items: [
      DropdownMenuItem(
        value: WorkspaceColumnMode.automatic,
        child: Text(context.l10n.appSettingsPageWorkspaceColumnModeAutomatic),
      ),
      DropdownMenuItem(
        value: WorkspaceColumnMode.forceList,
        child: Text(context.l10n.appSettingsPageWorkspaceColumnModeForceList),
      ),
      DropdownMenuItem(
        value: WorkspaceColumnMode.forceTwoColumns,
        child: Text(context.l10n.appSettingsPageWorkspaceColumnModeForceTwoColumns),
      ),
    ],
  );
}
