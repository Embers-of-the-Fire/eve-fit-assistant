import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:flutter/widgets.dart";

/// Carries the display-scoped configuration (icon resolver) down the tree.
class SnapshotDisplay extends InheritedWidget {
  const SnapshotDisplay({required this.resolver, required super.child, super.key});

  final EfaIconResolver? resolver;

  static EfaIconResolver? resolverOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SnapshotDisplay>()?.resolver;

  @override
  bool updateShouldNotify(SnapshotDisplay oldWidget) => resolver != oldWidget.resolver;
}

EfaItemState efaStateOf(Slots_SlotState state) => switch (state) {
  Slots_SlotState.ACTIVE => EfaItemState.active,
  Slots_SlotState.ONLINE => EfaItemState.online,
  Slots_SlotState.OVERLOAD => EfaItemState.overload,
  _ => EfaItemState.passive,
};
