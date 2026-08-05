@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/schema_guard/schema_guard.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/repo_error.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

void _ensureSchemaVersion() {
  final file = File(RepoPaths.schemaVersionPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode({"schemaVersion": 2}));
}

Widget _buildHarness(RepoState state) => ProviderScope(
  overrides: [
    repoStateProvider.overrideWithValue(state),
    localeProvider.overrideWithValue(Locale.zh),
  ],
  child: SchemaGuard(theme: ThemeData(useMaterial3: true), builder: (_) => const SizedBox()),
);

void main() {
  late String appSupportDir;

  setUp(() {
    appSupportDir = Directory.systemTemp.createTempSync("efa_schema_guard_support_").path;
    PathProvider.documentsPath = appSupportDir;
    PathProvider.appSupportPath = appSupportDir;
    _ensureSchemaVersion();
  });

  tearDown(() {
    final dir = Directory(appSupportDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  testWidgets("loading state renders a spinner without Directionality errors", (tester) async {
    await tester.pumpWidget(_buildHarness(const RepoState.initializing()));

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets("error state renders a retry screen without Directionality errors", (tester) async {
    await tester.pumpWidget(
      _buildHarness(const RepoState.error(error: RepoError.storage(message: "boom"))),
    );

    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text("boom"), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
