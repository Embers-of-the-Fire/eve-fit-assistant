import "package:flutter/widgets.dart";

/// Mutable holder shared between the tab scaffold and slidable wrappers.
///
/// The tab scaffold reads [pointerStartedOnEdge] on pointer-up to decide
/// whether a horizontal swipe should switch tabs; slidable edge zones write
/// it on pointer-down.
class SlidableEdgeTracker {
  bool pointerStartedOnEdge = false;
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

/// Wraps a slidable tile and splits its touch area into gesture zones.
///
/// Horizontal drags starting in the left or right [_edgeRatio] of the tile
/// are left to the wrapped slidable; drags starting in the center are claimed
/// by an overlay so the enclosing tab scaffold can use them to switch tabs.
/// Taps, long-presses and vertical scrolls are unaffected.
class SlidableEdgeZone extends StatelessWidget {
  const SlidableEdgeZone({required this.child, super.key});

  final Widget child;

  static const double _edgeRatio = 1.0 / 3.0;

  @override
  Widget build(BuildContext context) {
    final tracker = SlidableEdgeScope.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final edgeWidth = constraints.maxWidth * _edgeRatio;

        return Listener(
          onPointerDown: (event) {
            final box = context.findRenderObject();
            if (box is! RenderBox || !box.hasSize) return;
            final localX = box.globalToLocal(event.position).dx;
            final ratio = localX / box.size.width;
            tracker.pointerStartedOnEdge = ratio < _edgeRatio || ratio > 1.0 - _edgeRatio;
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
