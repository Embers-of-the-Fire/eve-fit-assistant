import "dart:async";
import "dart:math" as math;

import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Status indicator for the AppBar leading slot.
///
/// Displays a small animated ring during data loading, a soft glowing dot
/// when ready, and a warning icon on error.
class DataStatusIndicator extends ConsumerWidget {
  const DataStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readiness = ref.watch(dataReadinessProvider);
    final engineReady = ref.watch(
      nativeFitEngineServiceProvider.select((s) => s.engineOrNull != null),
    );

    final level = switch (readiness) {
      DataReadinessIdle() => DataReadinessLevel.idle,
      DataReadinessLoading() => DataReadinessLevel.collectionLoading,
      DataReadinessReady() =>
        engineReady ? DataReadinessLevel.fullyReady : DataReadinessLevel.collectionReady,
      DataReadinessError() => DataReadinessLevel.error,
    };

    if (level == DataReadinessLevel.idle) {
      return const SizedBox(width: 20, height: 20);
    }

    final tooltip = switch (level) {
      DataReadinessLevel.collectionLoading => context.l10n.dataStatusLoading,
      DataReadinessLevel.collectionReady => context.l10n.dataStatusEngineLoading,
      DataReadinessLevel.fullyReady => context.l10n.dataStatusReady,
      DataReadinessLevel.error => context.l10n.dataStatusError,
      DataReadinessLevel.idle => "",
    };

    return Tooltip(
      message: tooltip,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (level) {
            DataReadinessLevel.collectionLoading => const _LoadingRing(
              key: ValueKey("loading-collection"),
              color: Colors.amber,
            ),
            DataReadinessLevel.collectionReady => const _LoadingRing(
              key: ValueKey("loading-engine"),
              color: Colors.lightBlue,
            ),
            DataReadinessLevel.fullyReady => const _ReadyDot(key: ValueKey("ready")),
            DataReadinessLevel.error => const Icon(
              key: ValueKey("error"),
              Icons.error_outline_rounded,
              size: 18,
              color: Colors.redAccent,
            ),
            DataReadinessLevel.idle => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

/// A small spinning arc ring indicating active loading.
class _LoadingRing extends StatefulWidget {
  const _LoadingRing({required this.color, super.key});

  final Color color;

  @override
  State<_LoadingRing> createState() => _LoadingRingState();
}

class _LoadingRingState extends State<_LoadingRing> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => CustomPaint(
      size: const Size(18, 18),
      painter: _ArcPainter(progress: _controller.value, color: widget.color),
    ),
  );
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color.withAlpha(40);

    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color;

    const sweep = 0.65 * math.pi * 2;
    final startAngle = progress * math.pi * 2 - math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// A soft glowing dot indicating full readiness.
class _ReadyDot extends StatefulWidget {
  const _ReadyDot({super.key});

  @override
  State<_ReadyDot> createState() => _ReadyDotState();
}

class _ReadyDotState extends State<_ReadyDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: 0.7,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.green.withAlpha(80), blurRadius: 6, spreadRadius: 1)],
      ),
    ),
  );
}
