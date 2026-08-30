import "package:efa_fit/efa_fit.dart" show FitSnapshot;
import "package:efa_fit_snapshot/efa_fit_snapshot.dart";
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_test/flutter_test.dart";

import "fixture.dart";

Widget _wrap(Widget child, {Locale locale = const Locale("en")}) => MaterialApp(
  locale: locale,
  supportedLocales: const [Locale("en"), Locale("zh")],
  localizationsDelegates: const [
    SnapshotLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Scaffold(body: child),
);

Future<void> _pumpView(
  WidgetTester tester,
  FitSnapshot snapshot, {
  Locale locale = const Locale("en"),
  Size size = const Size(1400, 2400),
  bool showHeader = true,
  Widget? headerAction,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _wrap(
      FitSnapshotView(snapshot: snapshot, showHeader: showHeader, headerAction: headerAction),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("renders equipment, character and statistics columns (en)", (tester) async {
    await _pumpView(tester, buildFixtureSnapshot());

    expect(find.text("Test Rokh - Rokh"), findsOneWidget);
    expect(find.text("High Slot"), findsOneWidget);
    expect(find.text("425mm Railgun II"), findsOneWidget);
    expect(find.text("Antimatter Charge L"), findsOneWidget);
    expect(find.text("123.4 DPS"), findsOneWidget);
    expect(find.text("High Slot (Empty)"), findsNWidgets(7));
    expect(find.text("Hammerhead II"), findsOneWidget);
    expect(find.text("x 5"), findsOneWidget);
    expect(find.text("All 5"), findsOneWidget);
    expect(find.text("High-grade Halo Alpha"), findsOneWidget);
    expect(find.text("Standard Blue Pill"), findsOneWidget);
    expect(find.textContaining("35.0% Stable"), findsOneWidget);
    expect(find.textContaining("EHP"), findsWidgets);
    expect(find.text("99,500,000 kg"), findsOneWidget);
  });

  testWidgets("localizes chrome and type names (zh)", (tester) async {
    await _pumpView(tester, buildFixtureSnapshot(), locale: const Locale("zh"));

    expect(find.text("Test Rokh - 罗克级"), findsOneWidget);
    expect(find.text("高能量槽"), findsOneWidget);
    expect(find.text("425mm 磁轨炮 II"), findsOneWidget);
    expect(find.text("全 5"), findsOneWidget);
    expect(find.textContaining("稳定"), findsOneWidget);
  });

  testWidgets("renders without statistics", (tester) async {
    await _pumpView(tester, buildFixtureSnapshot(withStatistics: false));

    expect(find.text("High Slot"), findsOneWidget);
    expect(find.textContaining("Stable"), findsNothing);
  });

  testWidgets("renders the header action on the header row, beside the title", (tester) async {
    await _pumpView(tester, buildFixtureSnapshot(), headerAction: const Text("ACTION"));

    final title = tester.getRect(find.text("Test Rokh - Rokh"));
    final action = tester.getRect(find.text("ACTION"));

    expect(action.left, greaterThan(title.right));
    // Same row: the action's vertical center overlaps the title's.
    expect(action.center.dy, greaterThan(title.top));
    expect(action.center.dy, lessThan(title.bottom + 24));
  });

  testWidgets("omits the header action when the header is hidden", (tester) async {
    await _pumpView(
      tester,
      buildFixtureSnapshot(),
      showHeader: false,
      headerAction: const Text("ACTION"),
    );

    expect(find.text("Test Rokh - Rokh"), findsNothing);
    expect(find.text("ACTION"), findsNothing);
  });

  testWidgets("stacks into a single column on narrow layouts", (tester) async {
    await _pumpView(tester, buildFixtureSnapshot(), size: const Size(400, 3000));

    final equipment = tester.getRect(find.byType(SnapshotEquipmentColumn));
    final character = tester.getRect(find.byType(SnapshotCharacterColumn));
    final statistics = tester.getRect(find.byType(SnapshotStatisticsColumn));

    expect(equipment.left, character.left);
    expect(character.left, statistics.left);
    expect(equipment.width, character.width);
    expect(character.width, statistics.width);
    expect(equipment.bottom, lessThanOrEqualTo(character.top));
    expect(character.bottom, lessThanOrEqualTo(statistics.top));
  });

  testWidgets("arranges equipment beside stacked character and statistics on medium layouts", (
    tester,
  ) async {
    await _pumpView(tester, buildFixtureSnapshot(), size: const Size(1000, 3000));

    final equipment = tester.getRect(find.byType(SnapshotEquipmentColumn));
    final character = tester.getRect(find.byType(SnapshotCharacterColumn));
    final statistics = tester.getRect(find.byType(SnapshotStatisticsColumn));

    expect(equipment.right, lessThanOrEqualTo(character.left));
    expect(character.left, statistics.left);
    expect(character.bottom, lessThanOrEqualTo(statistics.top));
  });
}
