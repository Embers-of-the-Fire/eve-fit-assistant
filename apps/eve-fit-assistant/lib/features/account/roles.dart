import "package:efa_acl/efa_acl.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/widgets.dart";

/// Maps a stored ACL role key to its localized display label. Role keys are
/// internal vocabulary (see `packages/efa_acl`); the UI shows labels instead.
/// Unknown keys (e.g. a role added server-side before this build) render as
/// the raw key, so a new role degrades gracefully instead of breaking the page.
String accountRoleLabel(BuildContext context, String role) => switch (AclRole.tryByName(role)) {
  AclRole.user => context.l10n.accountRoleUser,
  AclRole.moderator => context.l10n.accountRoleModerator,
  AclRole.admin => context.l10n.accountRoleAdmin,
  null => role,
};
