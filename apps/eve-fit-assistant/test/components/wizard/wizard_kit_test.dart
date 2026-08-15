import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group("WizardOptionTile", () {
    testWidgets("radio control shows a check icon only when selected", (tester) async {
      await tester.pumpWidget(
        _host(WizardOptionTile(title: "English", selected: true, onTap: () {})),
      );
      expect(find.text("English"), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.pumpWidget(
        _host(WizardOptionTile(title: "English", selected: false, onTap: () {})),
      );
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets("checkbox control renders a Checkbox reflecting selection", (tester) async {
      await tester.pumpWidget(
        _host(
          WizardOptionTile(
            title: "Opt",
            selected: true,
            control: WizardOptionControl.checkbox,
            onTap: () {},
          ),
        ),
      );
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets("toggle control renders a Switch reflecting selection", (tester) async {
      await tester.pumpWidget(
        _host(
          WizardOptionTile(
            title: "Opt",
            selected: false,
            control: WizardOptionControl.toggle,
            onTap: () {},
          ),
        ),
      );
      final toggle = tester.widget<Switch>(find.byType(Switch));
      expect(toggle.value, isFalse);
    });

    testWidgets("renders the badge and forwards taps", (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(
          WizardOptionTile(
            title: "Stable",
            badge: "default",
            selected: false,
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text("default"), findsOneWidget);
      await tester.tap(find.text("Stable"));
      expect(tapped, isTrue);
    });
  });

  group("WizardActionBar", () {
    for (final layout in WizardActionBarLayout.values) {
      testWidgets("$layout renders primary and secondary actions and fires callbacks", (
        tester,
      ) async {
        var primary = false;
        var back = false;
        await tester.pumpWidget(
          _host(
            WizardActionBar(
              primaryLabel: "Continue",
              onPrimary: () => primary = true,
              layout: layout,
              secondary: [
                WizardAction(label: "Back", onPressed: () => back = true),
                const WizardAction(label: "Skip", onPressed: _noop),
              ],
            ),
          ),
        );

        expect(find.text("Continue"), findsOneWidget);
        expect(find.text("Back"), findsOneWidget);
        expect(find.text("Skip"), findsOneWidget);

        await tester.tap(find.text("Continue"));
        await tester.tap(find.text("Back"));
        expect(primary, isTrue);
        expect(back, isTrue);
      });
    }
  });

  group("WizardAsyncContent", () {
    testWidgets("shows a spinner while loading", (tester) async {
      await tester.pumpWidget(
        _host(
          WizardAsyncContent<int>(
            value: const AsyncLoading(),
            onRetry: _noop,
            errorMessage: "err",
            retryLabel: "Retry",
            builder: (data) => Text("data $data"),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets("shows the error message and a working retry button", (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _host(
          WizardAsyncContent<int>(
            value: AsyncError(Exception("boom"), StackTrace.empty),
            onRetry: () => retried = true,
            errorMessage: "Failed to load",
            retryLabel: "Retry",
            builder: (data) => Text("data $data"),
          ),
        ),
      );
      expect(find.text("Failed to load"), findsOneWidget);
      await tester.tap(find.text("Retry"));
      expect(retried, isTrue);
    });

    testWidgets("builds the data widget when available", (tester) async {
      await tester.pumpWidget(
        _host(
          WizardAsyncContent<int>(
            value: const AsyncData(42),
            onRetry: _noop,
            errorMessage: "err",
            retryLabel: "Retry",
            builder: (data) => Text("data $data"),
          ),
        ),
      );
      expect(find.text("data 42"), findsOneWidget);
    });
  });
}

void _noop() {}
