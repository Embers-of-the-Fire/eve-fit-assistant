import "dart:async";

import "package:eve_fit_assistant/components/dialog/info_dialog.dart";
import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path/path.dart" as p;
import "package:restart_app/restart_app.dart";

const _loadingKey = "storage-root-migrate";

/// Welcome step that lets the user choose where app data is stored. Only
/// shown on platforms where the storage root is editable (Windows).
class StorageStepPage extends ConsumerStatefulWidget {
  const StorageStepPage({
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  ConsumerState<StorageStepPage> createState() => _StorageStepPageState();
}

class _StorageStepPageState extends ConsumerState<StorageStepPage> {
  String? _customPath;
  bool _busy = false;

  Future<void> _pickCustom() async {
    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: context.l10n.welcomeStorageTitle,
    );
    if (selected != null && mounted) setState(() => _customPath = selected);
  }

  Future<void> _continue() async {
    final custom = _customPath;
    if (custom == null || p.equals(custom, PathProvider.appSupportPath)) {
      widget.onContinue();
      return;
    }

    final l10n = context.l10n;
    setState(() => _busy = true);
    GlobalLoading.addLocalized(_loadingKey, (l10n) => l10n.appSettingsPageStorageRootMigrating);
    try {
      await migrateStorageRootContents(custom);
      await StorageRootPreference.write(custom);
    } on Object catch (e) {
      GlobalLoading.dismiss(_loadingKey);
      if (mounted) {
        setState(() => _busy = false);
        await showInfoDialog(
          context,
          title: l10n.appSettingsPageStorageRootErrorTitle,
          content: Text("$e"),
        );
      }
      return;
    }
    GlobalLoading.dismiss(_loadingKey);
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = _customPath;

    return WizardScaffold(
      title: l10n.welcomeStorageTitle,
      subtitle: l10n.welcomeStorageSubtitle,
      primaryLabel: l10n.welcomeContinueButton,
      onPrimary: () => unawaited(_continue()),
      primaryEnabled: !_busy,
      secondaryActions: [
        WizardAction(label: l10n.welcomeBackButton, onPressed: widget.onBack),
        WizardAction(label: l10n.welcomeSkipButton, onPressed: widget.onSkip),
      ],
      content: WizardOptionList(
        children: [
          WizardOptionTile(
            title: l10n.welcomeStorageDefaultOption,
            subtitle: PathProvider.defaultAppSupportPath,
            selected: custom == null,
            onTap: () => setState(() => _customPath = null),
          ),
          WizardOptionTile(
            title: l10n.welcomeStorageCustomOption,
            subtitle: custom ?? l10n.welcomeStorageCustomHint,
            selected: custom != null,
            onTap: () => unawaited(_pickCustom()),
          ),
        ],
      ),
    );
  }
}
