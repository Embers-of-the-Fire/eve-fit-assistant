import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class TestProviderScope extends StatelessWidget {
  const TestProviderScope({super.key, this.overrides = const [], required this.child});

  final List<Override> overrides;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(overrides: overrides, child: child);
  }
}

extension TestContainerExt on ProviderContainer {
  void disposeAfter(WidgetTester tester) {
    tester.binding.addTearDown(dispose);
  }
}
