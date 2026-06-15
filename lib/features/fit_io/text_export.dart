import "dart:convert";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum FitTextExportFormat { native, eft }

class FitTextExportResult {
  const FitTextExportResult({required this.text, required this.lossy});

  final String text;
  final bool lossy;
}

class FitTextExporter {
  const FitTextExporter(this.ref);

  final WidgetRef ref;

  Future<FitTextExportResult> export({
    required FitStorage fit,
    required FitTextExportFormat format,
  }) async => switch (format) {
    FitTextExportFormat.native => FitTextExportResult(text: _exportNativeFit(fit), lossy: false),
    FitTextExportFormat.eft => FitTextExportResult(text: await _exportEft(fit), lossy: true),
  };

  String _exportNativeFit(FitStorage fit) {
    final payload = jsonEncode({"version": 1, "fit": fit.toJson()});
    final compressed = const GZipEncoder().encodeBytes(utf8.encode(payload), level: 9);
    return "EFA:${base64Encode(compressed)}";
  }

  Future<String> _exportEft(FitStorage fit) async {
    final names = await _FitTextNameResolver.load(ref);
    final sections = <String>[];

    final moduleSection = <String>[];
    for (final (slots, placeholder) in [
      (fit.body.slots.low, "[Empty Low slot]"),
      (fit.body.slots.medium, "[Empty Med slot]"),
      (fit.body.slots.high, "[Empty High slot]"),
      (fit.body.slots.rig, "[Empty Rig slot]"),
      (fit.body.slots.subsystem, "[Empty Subsystem slot]"),
      (fit.body.slots.service, "[Empty Service slot]"),
    ]) {
      if (slots.isEmpty) continue;

      final lines = <String>[];
      for (final slotOpt in slots) {
        slotOpt.match(() => lines.add(placeholder), (slot) {
          final moduleTypeId = _resolveEftModuleTypeId(fit, slot.itemId);
          final moduleName = names.typeName(moduleTypeId);
          final chargeSuffix = slot.charge.match(
            () => "",
            (charge) => ", ${names.typeName(charge.typeId)}",
          );
          final offlineSuffix = slot.state == FitItemState.passive ? " /offline" : "";
          lines.add("$moduleName$chargeSuffix$offlineSuffix");
        });
      }

      if (lines.isNotEmpty) {
        moduleSection.add(lines.join("\n"));
      }
    }
    if (moduleSection.isNotEmpty) {
      sections.add(moduleSection.join("\n\n"));
    }

    final minionSection = <String>[];
    if (fit.body.drones.isNotEmpty) {
      minionSection.add(
        fit.body.drones
            .map(
              (drone) =>
                  "${names.typeName(_resolveEftModuleTypeId(fit, drone.itemId))} x${drone.quantity}",
            )
            .join("\n"),
      );
    }
    if (fit.body.fighters.isNotEmpty) {
      minionSection.add(
        fit.body.fighters
            .map(
              (fighter) =>
                  "${names.typeName(_resolveEftModuleTypeId(fit, fighter.itemId))} x${fighter.quantity}",
            )
            .join("\n"),
      );
    }
    if (minionSection.isNotEmpty) {
      sections.add(minionSection.join("\n\n"));
    }

    final characterSection = <String>[];
    if (fit.body.implants.isNotEmpty) {
      characterSection.add(
        fit.body.implants
            .map((implant) => names.typeName(_resolveEftModuleTypeId(fit, implant.itemId)))
            .join("\n"),
      );
    }
    if (fit.body.boosters.isNotEmpty) {
      final boosters = fit.body.boosters.toList()
        ..sort((left, right) => left.index.compareTo(right.index));
      characterSection.add(
        boosters
            .map((booster) => names.typeName(_resolveEftModuleTypeId(fit, booster.itemId)))
            .join("\n"),
      );
    }
    if (characterSection.isNotEmpty) {
      sections.add(characterSection.join("\n\n"));
    }

    final shipName = names.typeName(fit.body.shipTypeId);
    final header = "[$shipName, ${fit.metadata.name}]";
    if (sections.isEmpty) {
      return "$header\n";
    }
    return "$header\n\n${sections.join("\n\n\n")}";
  }

  int _resolveEftModuleTypeId(FitStorage fit, FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) =>
        fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId ??
        fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId ??
        dynamicId,
  );
}

class _FitTextNameResolver {
  const _FitTextNameResolver({required this.ref});

  final WidgetRef ref;

  static Future<_FitTextNameResolver> load(WidgetRef ref) async => _FitTextNameResolver(ref: ref);

  String typeName(int typeId) {
    final type = ref.read(repoCollectionProvider)?.getType(typeId);
    if (type == null) {
      return "Unknown Type[$typeId]";
    }

    final localizationKey = type.typeName.id;
    return ref.read(repoCollectionProvider)?.getLocalizedName(localizationKey, "en") ??
        "Unknown Type[$typeId]";
  }
}
