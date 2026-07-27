import "dart:async";

import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Minimal status dot for the AppBar leading slot.
///
/// Reflects the composite data readiness level:
/// - idle: hidden (no active checkout)
/// - collectionLoading: amber pulse
/// - collectionReady: blue static
/// - fullyReady: green static
/// - error: red static
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

    final color = switch (level) {
      DataReadinessLevel.idle => Colors.transparent,
      DataReadinessLevel.collectionLoading => Colors.amber,
      DataReadinessLevel.collectionReady => Colors.lightBlue,
      DataReadinessLevel.fullyReady => Colors.green,
      DataReadinessLevel.error => Colors.redAccent,
    };

    if (level == DataReadinessLevel.idle) {
      return const SizedBox(width: 12, height: 12);
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
        child: level == DataReadinessLevel.collectionLoading
            ? _PulsingDot(color: color)
            : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
      begin: 0.4,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    ),
  );
}
