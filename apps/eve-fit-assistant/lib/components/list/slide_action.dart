import "dart:async";

import "package:efa_compat/io.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_slidable/flutter_slidable.dart";

const double _kActionExtentRatio = 0.15;
const int _kMaxVisibleActions = 2;

/// A sliding-tile action decoupled from its rendering, so the same definition
/// can be shown as a [SlidableAction] or as a dropdown menu entry.
class TileAction {
  const TileAction({
    required this.onPressed,
    required this.backgroundColor,
    this.icon,
    this.label,
    this.foregroundColor,
    this.autoClose = true,
    this.group,
  }) : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final Color backgroundColor;
  final Color? foregroundColor;
  final bool autoClose;

  /// Optional key identifying the action's visual group in dropdown menus.
  ///
  /// Menu entries are separated by a thin divider whenever the [group] of two
  /// adjacent actions differs (see [showTileActionsMenu]).
  final Object? group;

  final void Function(BuildContext context) onPressed;

  SlidableAction toSlidableAction() => SlidableAction(
    onPressed: onPressed,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    autoClose: autoClose,
    icon: icon,
    label: label,
    padding: .zero,
  );
}

/// Builds an [ActionPane] for one side of a tile.
///
/// Up to [_kMaxVisibleActions] actions are shown as-is. With more actions one
/// action stays visible and the rest fold into a dropdown overflow button.
/// The pinned visible action is the first one unless [overflowFirst] is set
/// (used by the end pane), in which case the last action — conventionally the
/// most fundamental one, e.g. remove — stays pinned at the outer edge while
/// the overflow button stays adjacent to the tile.
ActionPane? buildTileActionPane(List<TileAction> actions, {bool overflowFirst = false}) {
  if (actions.isEmpty) return null;
  if (actions.length <= _kMaxVisibleActions) {
    return ActionPane(
      extentRatio: _kActionExtentRatio * actions.length,
      motion: const StretchMotion(),
      children: [for (final action in actions) action.toSlidableAction()],
    );
  }
  return ActionPane(
    extentRatio: _kActionExtentRatio * _kMaxVisibleActions,
    motion: const StretchMotion(),
    children: [
      if (overflowFirst) ...[
        _OverflowTileActionButton(actions: actions.sublist(0, actions.length - 1)),
        actions.last.toSlidableAction(),
      ] else ...[
        actions.first.toSlidableAction(),
        _OverflowTileActionButton(actions: actions.sublist(1)),
      ],
    ],
  );
}

/// Opens a dropdown listing [actions] (icon + label, no background color) at
/// [position] and returns the selected action, if any.
///
/// A thin divider is inserted between adjacent actions whose
/// [TileAction.group] differs.
Future<TileAction?> showTileActionsMenu(
  BuildContext context,
  RelativeRect position,
  List<TileAction> actions,
) => showMenu<TileAction>(
  context: context,
  position: position,
  items: [
    for (final (index, action) in actions.indexed) ...[
      if (index > 0 && actions[index - 1].group != action.group) const PopupMenuDivider(),
      PopupMenuItem(
        value: action,
        child: Row(
          children: [
            if (action.icon != null) ...[Icon(action.icon, size: 20), const SizedBox(width: 12)],
            Expanded(child: Text(action.label ?? "")),
          ],
        ),
      ),
    ],
  ],
);

/// Invokes [selected], closing the enclosing [Slidable] first when
/// [TileAction.autoClose] is set.
void _dispatchTileAction(BuildContext context, TileAction selected) {
  if (selected.autoClose) unawaited(Slidable.of(context)?.close());
  selected.onPressed(context);
}

/// Flattens [actions] into dropdown order: actions sharing a
/// [TileAction.group] key become contiguous, following [groupOrder]; actions
/// without a group listed in [groupOrder] keep their relative order at the
/// end.
List<TileAction> flattenTileActionGroups(Iterable<TileAction> actions, List<Object> groupOrder) {
  final byGroup = <Object, List<TileAction>>{};
  final rest = <TileAction>[];
  for (final action in actions) {
    final group = action.group;
    if (group != null && groupOrder.contains(group)) {
      byGroup.putIfAbsent(group, () => []).add(action);
    } else {
      rest.add(action);
    }
  }
  return [for (final group in groupOrder) ...?byGroup[group], ...rest];
}

class _OverflowTileActionButton extends StatelessWidget {
  const _OverflowTileActionButton({required this.actions});

  final List<TileAction> actions;

  Future<void> _openMenu(BuildContext buttonContext) async {
    final box = buttonContext.findRenderObject()! as RenderBox;
    final selected = await showTileActionsMenu(
      buttonContext,
      RelativeRect.fromRect(
        box.localToGlobal(Offset.zero) & box.size,
        Offset.zero & MediaQuery.sizeOf(buttonContext),
      ),
      actions,
    );
    // The pane must stay mounted while the menu is open: closing the Slidable
    // unmounts this button, which would leave the selection unhandled.
    if (!buttonContext.mounted) return;
    if (selected == null) {
      unawaited(Slidable.of(buttonContext)?.close());
      return;
    }
    _dispatchTileAction(buttonContext, selected);
  }

  @override
  Widget build(BuildContext context) => CustomSlidableAction(
    onPressed: (buttonContext) => unawaited(_openMenu(buttonContext)),
    autoClose: false,
    backgroundColor: Colors.grey.shade200,
    foregroundColor: Colors.black,
    padding: .zero,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Flexible(child: Icon(Icons.more_vert)),
        const SizedBox(height: 4),
        Flexible(child: Text(context.l10n.more, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

bool get _supportsSecondaryActionMenu => !kIsWeb && (Platform.isWindows || Platform.isLinux);

/// Adds a desktop right-click dropdown listing all of a tile's slide actions.
///
/// On platforms other than Windows/Linux native (or when there are no
/// actions) this is a pass-through.
class TileSecondaryActionRegion extends StatelessWidget {
  const TileSecondaryActionRegion({required this.actions, required this.child, super.key});

  final List<TileAction> actions;
  final Widget child;

  Future<void> _openMenu(BuildContext context, Offset position) async {
    final selected = await showTileActionsMenu(
      context,
      RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      actions,
    );
    if (selected == null || !context.mounted) return;
    _dispatchTileAction(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsSecondaryActionMenu || actions.isEmpty) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => unawaited(_openMenu(context, details.globalPosition)),
      child: child,
    );
  }
}
