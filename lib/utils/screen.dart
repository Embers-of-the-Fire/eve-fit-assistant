import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/widgets.dart";

enum ScreenColumnTarget {
  one(1),
  two(2),
  three(3);

  const ScreenColumnTarget(this.count);

  final int count;
}

ScreenColumnTarget screenColumnTarget(BuildContext context) {
  const tabletMinWidth = 1000;
  const foldableMaxWidth = 900;
  const phoneMaxWidth = 600;

  const foldableAspectRatio = 0.9;
  const tabletAspectRatio = 1.4;

  final size = context.mediaQuery.size;
  final aspectRatio = size.width / size.height;

  if (size.width >= tabletMinWidth || aspectRatio >= tabletAspectRatio) {
    return ScreenColumnTarget.three;
  }
  if (aspectRatio >= foldableAspectRatio && aspectRatio <= tabletAspectRatio) {
    return ScreenColumnTarget.two;
  }
  if (size.width >= phoneMaxWidth && size.width < foldableMaxWidth) {
    return ScreenColumnTarget.two;
  }
  return ScreenColumnTarget.one;
}

int columnCount(BuildContext context) => screenColumnTarget(context).count;

bool supportsThreePaneLayout(BuildContext context) =>
    screenColumnTarget(context) == ScreenColumnTarget.three;
