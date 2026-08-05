import "package:eve_fit_assistant/data/proto/utils.pb.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

String _doNothingFormatter(String s) => s;

class LocalizedText extends ConsumerWidget {
  const LocalizedText({
    required this.localizationKey,
    super.key,
    this.formatter = _doNothingFormatter,
    this.textAlign,
  });

  final LocalizationID localizationKey;
  final String Function(String) formatter;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).name;
    final loc = ref.watch(localizedNameProvider(id: localizationKey.id, locale: locale)).value;

    return Text(
      (loc != null && loc.isNotEmpty) ? formatter(loc) : "LOC[${localizationKey.id}]",
      textAlign: textAlign,
    );
  }
}

class LocalizedTypeName extends ConsumerWidget {
  const LocalizedTypeName({required this.typeId, super.key, this.textAlign});

  final int typeId;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeNameId = ref.watch(
      repoCollectionProvider.select((c) => c?.getType(typeId)?.typeName),
    );
    if (typeNameId == null) {
      return Text(context.l10n.fallbackTypeUnavailable(typeId: typeId), textAlign: textAlign);
    }
    return LocalizedText(localizationKey: typeNameId, textAlign: textAlign);
  }
}
