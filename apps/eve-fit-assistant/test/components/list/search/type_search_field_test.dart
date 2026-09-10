import "dart:async";

import "package:eve_fit_assistant/components/list/search/type_search_field.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

import "../../../test_helpers.dart";

void main() {
  testWidgets("a stale search completing during a newer debounce is not reported", (tester) async {
    final pending = <String, Completer<List<int>>>{};
    Future<List<int>> searcher(String query, {int limit = 50}) =>
        (pending[query] = Completer<List<int>>()).future;
    final reported = <List<int>?>[];

    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: EveTypeSearchField(searcher: searcher, onResults: reported.add),
        ),
      ),
    );

    // Query A: debounce fires, search A starts and stays pending.
    await tester.enterText(find.byType(TextField), "aaa");
    await tester.pump(const Duration(milliseconds: 300));
    expect(pending, contains("aaa"));

    // Query B is entered; its debounce has not yet expired.
    await tester.enterText(find.byType(TextField), "bbb");

    // Search A completes during B's debounce window and must be dropped.
    pending["aaa"]!.complete([1]);
    await tester.pump();
    expect(reported, isEmpty);

    // B's debounce expires and its result is reported instead.
    await tester.pump(const Duration(milliseconds: 300));
    expect(pending, contains("bbb"));
    pending["bbb"]!.complete([2]);
    await tester.pump();
    expect(reported, [
      [2],
    ]);
  });
}
