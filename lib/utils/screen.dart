import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/widgets.dart";

int columnCount(BuildContext context) {
  const tabletMinWidth = 1000;
  const foldableMaxWidth = 900;
  const phoneMaxWidth = 600;

  const foldableAspectRatio = 0.9;
  const tabletAspectRatio = 1.4;

  final size = context.mediaQuery.size;
  final aspectRatio = size.width / size.height;

  int columns = 1;

  if (size.width >= tabletMinWidth || aspectRatio >= tabletAspectRatio) {
    columns = 3;
  } else if (aspectRatio >= foldableAspectRatio && aspectRatio <= tabletAspectRatio) {
    columns = 2;
  } else if (size.width >= phoneMaxWidth && size.width < foldableMaxWidth) {
    columns = 2;
  }

  return columns;
}
