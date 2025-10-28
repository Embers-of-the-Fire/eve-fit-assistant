import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";

class FitDisplayColumns extends StatelessWidget {
  const FitDisplayColumns({required this.fit, required this.fitMetadata, super.key});

  final FitMetadata fitMetadata;
  final FitStorage fit;

  @override
  Widget build(BuildContext context) {
    final columns = columnCount(context);
    final size = context.mediaQuery.size;
    final aspectRatio = size.width / size.height;

    return Column(
      children: [
        Text("$columns, $size, $aspectRatio"),
        Expanded(
          child: Row(
            children: Expanded(
              child: FitDisplayColumn(fit: fit, fitMetadata: fitMetadata),
            ).repeat(columns).toList(),
          ),
        ),
      ],
    );
  }
}

class FitDisplayColumn extends StatelessWidget {
  const FitDisplayColumn({required this.fit, required this.fitMetadata, super.key});

  final FitMetadata fitMetadata;
  final FitStorage fit;

  @override
  Widget build(BuildContext context) =>
      Center(child: Column(children: [Text("$fitMetadata\n"), Text("$fit\n")]));
}
