import "package:eve_fit_assistant/data/proto/utils.pb.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
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

    return Text(loc.map(formatter) ?? "LOC[${localizationKey.id}]");
  }
}

class LocalizedTypeName extends ConsumerWidget {
  const LocalizedTypeName({required this.typeId, super.key});

  final int typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeNameId = ref.watch(
      bundleCollectionGetTypeProvider(typeId).select((t) => t?.typeName),
    );
    if (typeNameId == null) {
      return Text("Unknown Type[$typeId]");
    }
    return LocalizedText(localizationKey: typeNameId);
  }
}
