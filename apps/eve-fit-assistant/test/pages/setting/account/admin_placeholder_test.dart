@TestOn("vm")
library;

import "package:efa_acl/efa_acl.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/pages/setting/account/admin_placeholder.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "../../../test_helpers.dart";

/// Pumps the placeholder with the account ACL resolved from [roles], mirroring
/// how the account page gates the block on the signed-in account's roles.
Widget buildPlaceholder(List<String> roles) => ProviderScope(
  overrides: [accountAclProvider.overrideWith((ref) async => aclForRoles(roles))],
  child: testApp(const Material(child: AccountAdminPlaceholder())),
);

void main() {
  testWidgets("shows the placeholder when the account holds the admin permission", (tester) async {
    await tester.pumpWidget(buildPlaceholder(["user", "admin"]));
    await tester.pumpAndSettle();

    expect(find.text("管理"), findsOneWidget);
    expect(find.text("管理员功能区（占位）"), findsOneWidget);
  });

  testWidgets("hides the placeholder without the admin permission", (tester) async {
    await tester.pumpWidget(buildPlaceholder(["user", "moderator"]));
    await tester.pumpAndSettle();

    expect(find.text("管理"), findsNothing);
    expect(find.text("管理员功能区（占位）"), findsNothing);
  });

  testWidgets("hides the placeholder while signed out (empty ACL)", (tester) async {
    await tester.pumpWidget(buildPlaceholder(const []));
    await tester.pumpAndSettle();

    expect(find.text("管理员功能区（占位）"), findsNothing);
  });
}
