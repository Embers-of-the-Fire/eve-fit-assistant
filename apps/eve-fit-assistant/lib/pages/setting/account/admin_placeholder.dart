import "package:efa_acl/efa_acl.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Placeholder admin-area block on the account page, exercising client-side
/// ACL gating: visible only when the signed-in account's resolved permissions
/// include the `admin:manage_roles` token. This is a UI filter only; the
/// platform API enforces the real authorization.
class AccountAdminPlaceholder extends ConsumerWidget {
  const AccountAdminPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(
      accountAclProvider.select((acl) => acl.value?.canAdminManageRoles() ?? false),
    );
    if (!isAdmin) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const .only(left: 16, top: 24, bottom: 4),
          child: Text(
            context.l10n.accountAdminSection,
            style: context.theme.textTheme.titleMedium?.copyWith(color: context.theme.hintColor),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.admin_panel_settings_outlined),
          title: Text(context.l10n.accountAdminPlaceholderTitle),
          subtitle: Text(context.l10n.accountAdminPlaceholderSubtitle),
        ),
      ],
    );
  }
}
