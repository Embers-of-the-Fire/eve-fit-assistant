import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/account/roles.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/account/admin_placeholder.dart";
import "package:eve_fit_assistant/pages/setting/account/errors.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(platformIdentityProvider);
    return Layout(
      title: context.l10n.accountPageTitle,
      child: switch (identity) {
        AsyncData(:final value) =>
          value == null ? const _SignedOutView() : _SignedInView(identity: value),
        AsyncError() => const _SignedOutView(),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) => ConfigListView(
    children: [
      const ConfigListTile.space(20),
      ConfigListTile.item(
        icon: const Icon(Icons.login_outlined),
        title: context.l10n.accountSignInTileTitle,
        subtitle: context.l10n.accountSignInTileSubtitle,
        onTap: () => unawaited(context.router.push(const AccountLoginRoute())),
      ),
      ConfigListTile.item(
        icon: const Icon(Icons.person_add_alt_outlined),
        title: context.l10n.accountRegisterTileTitle,
        subtitle: context.l10n.accountRegisterTileSubtitle,
        onTap: () => unawaited(context.router.push(AccountRegisterRoute())),
      ),
    ],
  );
}

class _SignedInView extends ConsumerWidget {
  const _SignedInView({required this.identity});

  final PlatformIdentity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountInfo = ref.watch(platformAccountInfoProvider);
    final roles = accountInfo.value?.roles ?? const <String>[];
    final roleLabels = roles.map((role) => accountRoleLabel(context, role)).join(", ");
    return ConfigListView(
      children: [
        ConfigListTile.title(context.l10n.accountSignedInSection),
        ConfigListTile.custom(
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(identity.email),
            subtitle: Text(
              "${context.l10n.accountUserIdLabel}: ${identity.userId}"
              "${roles.isEmpty ? "" : "\n${context.l10n.accountRolesLabel}: $roleLabels"}",
            ),
          ),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.logout_outlined),
          title: context.l10n.accountLogoutTileTitle,
          onTap: () => unawaited(_logout(context, ref)),
        ),
        ConfigListTile.item(
          icon: const Icon(Icons.person_remove_outlined),
          title: context.l10n.accountDeregisterTileTitle,
          onTap: () => unawaited(_deregister(context, ref)),
        ),
        const ConfigListTile.custom(AccountAdminPlaceholder()),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.accountLogoutConfirmTitle,
      content: Text(context.l10n.accountLogoutConfirmDescription),
    );
    if (!confirmed || !context.mounted) return;
    try {
      final session = await ref.read(platformSessionProvider.future);
      await session.logout();
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accountErrorMessage(context, e))));
    }
  }

  Future<void> _deregister(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.accountDeregisterConfirmTitle,
      content: Text(context.l10n.accountDeregisterConfirmDescription),
    );
    if (!confirmed || !context.mounted) return;
    final password = await _promptPassword(context);
    if (password == null || !context.mounted) return;
    try {
      final session = await ref.read(platformSessionProvider.future);
      await session.deregister(password: password);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(accountErrorMessage(context, e))));
    }
  }

  Future<String?> _promptPassword(BuildContext context) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.accountDeregisterTileTitle,
        content: TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.l10n.accountDeregisterPasswordPrompt,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (saved != true) {
      controller.dispose();
      return null;
    }
    final password = controller.text;
    controller.dispose();
    return password.isEmpty ? null : password;
  }
}
