import "package:eve_fit_assistant/config/list_tile_anti_scroll.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Mutable holder shared between the tab scaffold and slidable wrappers.
///
/// The tab scaffold calls [consumeOnEdge] on pointer-up to decide whether a
/// horizontal swipe should switch tabs; slidable edge zones call [setOnEdge]
/// on pointer-down. State is keyed by pointer ID so concurrent touches do not
/// interfere.
class SlidableEdgeTracker {
  final Map<int, bool> _onEdge = {};

  void setOnEdge(int pointer, {required bool value}) {
    _onEdge[pointer] = value;
  }

  bool consumeOnEdge(int pointer) => _onEdge.remove(pointer) ?? false;

  void clear(int pointer) {
    _onEdge.remove(pointer);
  }
}

/// Provides a [SlidableEdgeTracker] to descendant [SlidableEdgeZone]s.
class SlidableEdgeScope extends InheritedWidget {
  const SlidableEdgeScope({required this.tracker, required super.child, super.key});

  final SlidableEdgeTracker tracker;

  static SlidableEdgeTracker of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SlidableEdgeScope>()!.tracker;

  @override
  bool updateShouldNotify(covariant SlidableEdgeScope oldWidget) => tracker != oldWidget.tracker;
}

/// Wraps a slidable tile's content and splits its touch area into gesture
/// zones.
///
/// Place this widget as the Slidable's child so the zones travel with the
/// visible content when actions are revealed. Horizontal drags starting in
/// the left or right edge zones of the content are left to the enclosing
/// slidable; drags starting in the center zone are claimed by an overlay so
/// the tab scaffold can use them to switch tabs. Taps, long-presses and
/// vertical scrolls are unaffected. The width of the center zone is
/// configured by the [AppSetting.listTileAntiScrollLevel] setting.
///
/// When the level is [ListTileAntiScrollLevel.closed], the protection is
/// disabled: no zones are installed, the slidable keeps its raw behavior, and
/// drags starting on the tile never switch tabs.
class SlidableEdgeZone extends ConsumerWidget {
  const SlidableEdgeZone({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = SlidableEdgeScope.of(context);
    final level = ref.watch(appSettingServiceProvider.select((s) => s.listTileAntiScrollLevel));

    if (level == ListTileAntiScrollLevel.closed) {
      return Listener(
        onPointerDown: (event) => tracker.setOnEdge(event.pointer, value: true),
        child: child,
      );
    }

    final edgeRatio = (1.0 - level.centerRatio) / 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final edgeWidth = constraints.maxWidth * edgeRatio;

        return Listener(
          onPointerDown: (event) {
            final box = context.findRenderObject();
            if (box is! RenderBox || !box.hasSize) return;
            final localX = box.globalToLocal(event.position).dx;
            final ratio = localX / box.size.width;
            tracker.setOnEdge(event.pointer, value: ratio < edgeRatio || ratio > 1.0 - edgeRatio);
          },
          child: Stack(
            children: [
              child,
              Positioned(
                left: edgeWidth,
                right: edgeWidth,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
