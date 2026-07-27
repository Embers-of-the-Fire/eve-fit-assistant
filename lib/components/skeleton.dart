import "dart:async";

import "package:flutter/material.dart";

/// A shimmer-animated placeholder box used to build skeleton loading layouts.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({required this.width, required this.height, this.borderRadius = 4, super.key});

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.5,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton layout mimicking a fit page (ship header + slot rows).
class FitPageSkeleton extends StatelessWidget {
  const FitPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            ShimmerBox(width: 48, height: 48, borderRadius: 8),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 160, height: 16),
                  SizedBox(height: 8),
                  ShimmerBox(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 6; i++) ...[
          const Row(
            children: [
              ShimmerBox(width: 36, height: 36, borderRadius: 6),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(width: double.infinity, height: 14)),
              SizedBox(width: 8),
              ShimmerBox(width: 48, height: 14),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

/// Skeleton layout mimicking a list of selectable items (e.g. ship browser).
class SelectListSkeleton extends StatelessWidget {
  const SelectListSkeleton({this.itemCount = 6, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) => ListView.builder(
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 8),
    itemCount: itemCount,
    itemBuilder: (context, index) => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          ShimmerBox(width: 40, height: 40, borderRadius: 6),
          SizedBox(width: 12),
          Expanded(child: ShimmerBox(width: double.infinity, height: 14)),
        ],
      ),
    ),
  );
}
