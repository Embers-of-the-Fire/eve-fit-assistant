part of "page.dart";

const _storageRootLoadingKey = "storage-root-migrate";

class StorageRootTile extends ConsumerStatefulWidget {
  const StorageRootTile({super.key});

  @override
  ConsumerState<StorageRootTile> createState() => _StorageRootTileState();
}

class _StorageRootTileState extends ConsumerState<StorageRootTile> {
  String? _configuredRoot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final root = await StorageRootPreference.read();
    if (mounted) setState(() => _configuredRoot = root);
  }

  bool get _isCustom =>
      _configuredRoot != null && !p.equals(_configuredRoot!, PathProvider.defaultAppSupportPath);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(l10n.appSettingsPageStorageRootTitle),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            PathProvider.appSupportPath,
            style: context.theme.textTheme.bodySmall?.copyWith(
              fontFamily: "monospace",
              color: context.theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isCustom
                ? l10n.appSettingsPageStorageRootDescription
                : l10n.appSettingsPageStorageRootDefaultDescription,
            style: context.theme.textTheme.bodySmall,
          ),
        ],
      ),
      trailing: _isCustom
          ? TextButton(
              onPressed: _busy ? null : () => unawaited(_resetToDefault(context)),
              child: Text(l10n.appSettingsPageStorageRootResetButton),
            )
          : null,
      onTap: _busy ? null : () => unawaited(_change(context)),
    );
  }

  Future<void> _change(BuildContext context) async {
    final l10n = context.l10n;
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: l10n.appSettingsPageStorageRootTitle,
    );
    if (selected == null || !context.mounted) return;
    if (p.equals(selected, PathProvider.appSupportPath)) return;

    final confirmed = await showConfirmDialog(
      context,
      title: l10n.appSettingsPageStorageRootChangeConfirmTitle,
      content: Text(l10n.appSettingsPageStorageRootChangeConfirmDescription(path: selected)),
    );
    if (!confirmed || !context.mounted) return;
    await _apply(context, selected);
  }

  Future<void> _resetToDefault(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.appSettingsPageStorageRootResetConfirmTitle,
      content: Text(l10n.appSettingsPageStorageRootResetConfirmDescription),
    );
    if (!confirmed || !context.mounted) return;
    await _apply(context, PathProvider.defaultAppSupportPath);
  }

  Future<void> _apply(BuildContext context, String newRoot) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    GlobalLoading.addLocalized(
      _storageRootLoadingKey,
      (l10n) => l10n.appSettingsPageStorageRootMigrating,
    );
    try {
      await migrateStorageRootContents(newRoot);
      final isDefault = p.equals(newRoot, PathProvider.defaultAppSupportPath);
      await StorageRootPreference.write(isDefault ? null : newRoot);
    } on Object catch (e) {
      GlobalLoading.dismiss(_storageRootLoadingKey);
      if (context.mounted) {
        await showInfoDialog(
          context,
          title: l10n.appSettingsPageStorageRootErrorTitle,
          content: Text("$e"),
        );
      }
      if (mounted) setState(() => _busy = false);
      return;
    }
    GlobalLoading.dismiss(_storageRootLoadingKey);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.appSettingsPageStorageRootRestartTitle),
        content: Text(l10n.appSettingsPageStorageRootRestartDescription),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(l10n.appSettingsPageStorageRootRestartButton),
          ),
        ],
      ),
    );
    await Restart.restartApp();
  }
}
