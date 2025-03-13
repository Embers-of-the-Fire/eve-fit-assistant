import 'package:flutter/material.dart';

class FixedHeightGridView extends StatelessWidget {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childHeight;
  final List<Widget> children;
  final EdgeInsets? padding;
  final ScrollController? controller;

  const FixedHeightGridView({
    super.key,
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.childHeight,
    required this.children,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) => GridView.count(
        padding: padding,
        controller: controller,
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: _calculateChildAspectRatio(context),
        children: children,
      );

  double _calculateChildAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = crossAxisSpacing * (crossAxisCount - 1);
    final itemWidth = (screenWidth - horizontalPadding) / crossAxisCount;
    return itemWidth / childHeight;
  }
}
