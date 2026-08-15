import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_export.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

enum FitTextExportFormat { native, eft, snapshot }

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
    String? fitId,
  }) async => switch (format) {
    FitTextExportFormat.native => FitTextExportResult(text: _exportNativeFit(fit), lossy: false),
    FitTextExportFormat.eft => FitTextExportResult(text: await _exportEft(fit), lossy: true),
    FitTextExportFormat.snapshot => FitTextExportResult(
      text: await FitSnapshotExporter(ref).export(fitId: fitId!, fit: fit),
      lossy: false,
    ),
  };

  String _exportNativeFit(FitStorage fit) => encodeEfaFitTextPayload(encodeNativeFitPayload(fit));

  Future<String> _exportEft(FitStorage fit) async {
    final names = await FitTypeNameResolver.load(ref, fit);
    return formatEft(_toEftFit(fit), typeName: names.typeName);
  }

  EftFit _toEftFit(FitStorage fit) {
    final racks = <EftRack, List<EftModule?>>{};
    for (final (rack, slots) in [
      (EftRack.low, fit.body.slots.low),
      (EftRack.medium, fit.body.slots.medium),
      (EftRack.high, fit.body.slots.high),
      (EftRack.rig, fit.body.slots.rig),
      (EftRack.subsystem, fit.body.slots.subsystem),
      (EftRack.service, fit.body.slots.service),
    ]) {
      if (slots.isEmpty) continue;
      racks[rack] = [
        for (final slotOpt in slots)
          slotOpt.match(
            () => null,
            (slot) => EftModule(
              typeId: _resolveEftModuleTypeId(fit, slot.itemId),
              chargeTypeId: slot.charge.match(() => null, (charge) => charge.typeId),
              online: slot.state != FitItemState.passive,
            ),
          ),
      ];
    }

    final boosters = fit.body.boosters.toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return EftFit(
      shipTypeId: fit.body.shipTypeId,
      name: fit.metadata.name,
      racks: racks,
      drones: [
        for (final drone in fit.body.drones)
          EftStack(typeId: _resolveEftModuleTypeId(fit, drone.itemId), quantity: drone.quantity),
      ],
      fighters: [
        for (final fighter in fit.body.fighters)
          EftStack(
            typeId: _resolveEftModuleTypeId(fit, fighter.itemId),
            quantity: fighter.quantity,
          ),
      ],
      implants: [
        for (final implant in fit.body.implants) _resolveEftModuleTypeId(fit, implant.itemId),
      ],
      boosters: [
        for (final booster in boosters)
          EftSlottedItem(
            typeId: _resolveEftModuleTypeId(fit, booster.itemId),
            slotIndex: booster.index,
          ),
      ],
    );
  }

  int _resolveEftModuleTypeId(FitStorage fit, FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) =>
        fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId ??
        fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId ??
        dynamicId,
  );
}

class FitTypeNameResolver {
  const FitTypeNameResolver({required this.typeNames});

  final Map<int, String> typeNames;

  /// Pre-resolves the English names of every item referenced by [fit].
  ///
  /// EFT export names always use the `"en"` locale; the names are batch-loaded
  /// from the checkout's localization database in a single pass instead of
  /// being looked up one by one from an eagerly decoded map.
  static Future<FitTypeNameResolver> load(WidgetRef ref, FitStorage fit) async {
    final collection = ref.read(repoCollectionProvider);

    final typeIds = <int>{fit.body.shipTypeId};
    void collect(FitStorageItemId itemId) => typeIds.add(_resolveItemId(fit, itemId));

    final slotLists = [
      fit.body.slots.low,
      fit.body.slots.medium,
      fit.body.slots.high,
      fit.body.slots.rig,
      fit.body.slots.subsystem,
      fit.body.slots.service,
    ];
    for (final slots in slotLists) {
      for (final slotOpt in slots) {
        slotOpt.map((slot) {
          collect(slot.itemId);
          slot.charge.map((charge) => typeIds.add(charge.typeId));
        });
      }
    }
    if (fit.body.slots.tacticalMode case Some(:final value)) {
      typeIds.add(value);
    }
    for (final drone in fit.body.drones) {
      collect(drone.itemId);
    }
    for (final fighter in fit.body.fighters) {
      collect(fighter.itemId);
    }
    for (final implant in fit.body.implants) {
      collect(implant.itemId);
    }
    for (final booster in fit.body.boosters) {
      collect(booster.itemId);
    }

    final localizationKeys = <int>[];
    for (final typeId in typeIds) {
      final type = collection?.getType(typeId);
      if (type != null) localizationKeys.add(type.typeName.id);
    }

    final service = await ref.read(localizationDbServiceProvider.future);
    final names = await service?.localizedNames(localizationKeys, "en") ?? const <int, String>{};

    final typeNames = <int, String>{};
    for (final typeId in typeIds) {
      final type = collection?.getType(typeId);
      final name = type != null ? names[type.typeName.id] : null;
      if (name != null && name.isNotEmpty) typeNames[typeId] = name;
    }

    return FitTypeNameResolver(typeNames: typeNames);
  }

  static int _resolveItemId(FitStorage fit, FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) =>
        fit.dynamicRegistry.dynamicItems[dynamicId]?.originTypeId ??
        fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId ??
        dynamicId,
  );

  String typeName(int typeId) => typeNames[typeId] ?? "Unknown Type[$typeId]";
}
