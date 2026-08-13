import "package:eve_fit_assistant/compat/io.dart" show Platform;
import "package:eve_fit_assistant/components/list/slide_action.dart";
import "package:flutter/gestures.dart";
import "package:flutter/material.dart";
import "package:flutter_slidable/flutter_slidable.dart";
import "package:flutter_test/flutter_test.dart";

import "../../test_helpers.dart";

TileAction _action(String label, void Function() onInvoke) =>
    TileAction(onPressed: (_) => onInvoke(), backgroundColor: Colors.grey, label: label);

Widget _slidableTile(List<TileAction> actions) => Scaffold(
  body: Slidable(
    startActionPane: buildTileActionPane(actions),
    child: const ListTile(title: Text("tile")),
  ),
);

Future<void> _openStartPane(WidgetTester tester) async {
  await tester.drag(find.text("tile"), const Offset(300, 0));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("two actions are shown as-is without overflow", (tester) async {
    await tester.pumpWidget(testApp(_slidableTile([_action("A", () {}), _action("B", () {})])));

    await _openStartPane(tester);

    expect(find.text("A"), findsOneWidget);
    expect(find.text("B"), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets("three actions fold into overflow menu that invokes the selection", (tester) async {
    final invoked = <String>[];
    await tester.pumpWidget(
      testApp(
        _slidableTile([
          _action("A", () => invoked.add("A")),
          _action("B", () => invoked.add("B")),
          _action("C", () => invoked.add("C")),
        ]),
      ),
    );

    await _openStartPane(tester);

    expect(find.text("A"), findsOneWidget);
    expect(find.text("B"), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text("B"), findsOneWidget);
    expect(find.text("C"), findsOneWidget);

    await tester.tap(find.text("C"));
    await tester.pumpAndSettle();

    expect(invoked, ["C"]);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets("dismissing the overflow menu invokes nothing and closes the pane", (tester) async {
    final invoked = <String>[];
    await tester.pumpWidget(
      testApp(
        _slidableTile([
          _action("A", () {}),
          _action("B", () => invoked.add("B")),
          _action("C", () {}),
        ]),
      ),
    );

    await _openStartPane(tester);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(invoked, isEmpty);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets(
    "secondary tap lists all actions and invokes the selection",
    (tester) async {
      final invoked = <String>[];
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: TileSecondaryActionRegion(
              actions: [_action("A", () => invoked.add("A")), _action("B", () => invoked.add("B"))],
              child: const ListTile(title: Text("tile")),
            ),
          ),
        ),
      );

      await tester.tap(find.text("tile"), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text("A"), findsOneWidget);
      expect(find.text("B"), findsOneWidget);

      await tester.tap(find.text("B"));
      await tester.pumpAndSettle();

      expect(invoked, ["B"]);
    },
    skip: !(Platform.isWindows || Platform.isLinux),
  );
}
