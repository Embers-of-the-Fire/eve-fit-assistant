import "package:eve_fit_assistant/components/card/homepage_link_card.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/config/workspace_layout.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/pages/workspace/page.dart";
import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "../../test_helpers.dart";

AppSetting _appSetting({
  WorkspaceTileStyle tileStyle = WorkspaceTileStyle.automatic,
  WorkspaceColumnMode columnMode = WorkspaceColumnMode.automatic,
}) => AppSetting(
  locale: Locale.zh,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  workspaceTileStyle: tileStyle,
  workspaceColumnMode: columnMode,
);

Widget _buildWorkspace({
  required double width,
  WorkspaceTileStyle tileStyle = WorkspaceTileStyle.automatic,
  WorkspaceColumnMode columnMode = WorkspaceColumnMode.automatic,
}) => ProviderScope(
  overrides: [
    appSettingServiceProvider.overrideWithValue(
      _appSetting(tileStyle: tileStyle, columnMode: columnMode),
    ),
    batchDataUpdateControllerProvider.overrideWithValue(const BatchDataUpdateStatus.unknown()),
    unreadAnnouncementCountProvider.overrideWithValue(0),
    pendingVersionBumpProvider.overrideWithValue(false),
  ],
  child: testApp(
    Scaffold(
      body: Center(
        child: SizedBox(width: width, height: 600, child: const WorkspacePage()),
      ),
    ),
  ),
);

void main() {
  testWidgets("one-column width renders compact list cards", (tester) async {
    await tester.pumpWidget(_buildWorkspace(width: 320));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    final cards = tester.widgetList<HomepageLinkCard>(find.byType(HomepageLinkCard)).toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.compact), isTrue);
    expect(find.byType(ListTile), findsNWidgets(cards.length));

    final firstCard = find.descendant(
      of: find.byType(HomepageLinkCard).first,
      matching: find.byType(Card),
    );
    final cardSize = tester.getSize(firstCard);
    expect(cardSize.height, lessThan(cardSize.width));
  });

  testWidgets("multi-column width retains square grid cards", (tester) async {
    await tester.pumpWidget(_buildWorkspace(width: 700));

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    final cards = tester.widgetList<HomepageLinkCard>(find.byType(HomepageLinkCard)).toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => !card.compact), isTrue);
  });

  testWidgets("compact style applies to responsive multi-column rows", (tester) async {
    await tester.pumpWidget(_buildWorkspace(width: 700, tileStyle: WorkspaceTileStyle.compact));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);

    final cards = tester.widgetList<HomepageLinkCard>(find.byType(HomepageLinkCard)).toList();
    expect(cards, isNotEmpty);
    expect(cards.every((card) => card.compact), isTrue);

    final firstPosition = tester.getTopLeft(find.byType(HomepageLinkCard).first);
    final secondPosition = tester.getTopLeft(find.byType(HomepageLinkCard).at(1));
    expect(secondPosition.dy, firstPosition.dy);
    expect(secondPosition.dx, greaterThan(firstPosition.dx));
  });

  testWidgets("forced two columns places two compact cards in the first row", (tester) async {
    await tester.pumpWidget(
      _buildWorkspace(
        width: 320,
        tileStyle: WorkspaceTileStyle.compact,
        columnMode: WorkspaceColumnMode.forceTwoColumns,
      ),
    );

    final firstPosition = tester.getTopLeft(find.byType(HomepageLinkCard).first);
    final secondPosition = tester.getTopLeft(find.byType(HomepageLinkCard).at(1));
    final thirdPosition = tester.getTopLeft(find.byType(HomepageLinkCard).at(2));
    expect(secondPosition.dy, firstPosition.dy);
    expect(secondPosition.dx, greaterThan(firstPosition.dx));
    expect(thirdPosition.dy, greaterThan(firstPosition.dy));
  });

  testWidgets("forced two columns with automatic style uses a square grid", (tester) async {
    await tester.pumpWidget(
      _buildWorkspace(width: 320, columnMode: WorkspaceColumnMode.forceTwoColumns),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);

    final cards = tester.widgetList<HomepageLinkCard>(find.byType(HomepageLinkCard));
    expect(cards.every((card) => !card.compact), isTrue);
  });

  testWidgets("forced list can retain square cards", (tester) async {
    await tester.pumpWidget(
      _buildWorkspace(
        width: 320,
        tileStyle: WorkspaceTileStyle.square,
        columnMode: WorkspaceColumnMode.forceList,
      ),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 1);

    final cards = tester.widgetList<HomepageLinkCard>(find.byType(HomepageLinkCard));
    expect(cards.every((card) => !card.compact), isTrue);
  });
}
