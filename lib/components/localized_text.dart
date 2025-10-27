import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/utils.pb.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

String _doNothingFormatter(String s) => s;

class LocalizedText extends ConsumerWidget {
  const LocalizedText({
    required this.localizationKey,
    super.key,
    this.formatter = _doNothingFormatter,
  });

  final LocalizationID localizationKey;
  final String Function(String) formatter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationProvider(localizationKey.id));

    return Text(
      loc.when(
        data: (data) => data.map(formatter) ?? "LOC[$localizationKey]",
        error: (err, stackTrace) {
          error("Localization error for key $localizationKey: $err", stackTrace: stackTrace);
          return "UNKNOWN[$localizationKey]";
        },
        loading: () => context.l10n.loading,
      ),
    );
  }
}
