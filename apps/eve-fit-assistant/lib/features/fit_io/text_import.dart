import "package:efa_constant/eve.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

enum FitTextImportErrorCode {
  emptyInput,
  unsupportedFormat,
  unsupportedFittingLink,
  unsupportedNativeVersion,
  invalidNativePayload,
  invalidEft,
  unknownType,
  unavailableShip,
  unavailableData,
}

class FitTextImportException implements Exception {
  const FitTextImportException(this.code, {this.detail});

  final FitTextImportErrorCode code;
  final String? detail;

  @override
  String toString() => "FitTextImportException($code, detail: $detail)";
}

class FitTextImporter {
  const FitTextImporter(this.ref);

  static final _nativePrefixPattern = RegExp(r"^EFA(?:(\d+))?:");

  final WidgetRef ref;

  Future<FitMetadata> importText(String input) async {
    final fit = await parse(input);
    return ref.read(fitManagerProvider.notifier).importFit(fit);
  }

  Future<FitStorage> parse(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw const FitTextImportException(FitTextImportErrorCode.emptyInput);
    }

    if (_nativePrefixPattern.hasMatch(text)) {
      return _parseNative(text);
    }

    if (text.startsWith("fitting:")) {
      throw const FitTextImportException(FitTextImportErrorCode.unsupportedFittingLink);
    }

    if (text.startsWith("[") && text.contains("]")) {
      return _parseEft(text);
    }

    throw const FitTextImportException(FitTextImportErrorCode.unsupportedFormat);
  }

  FitStorage _parseNative(String text) {
    final EfaFitTextPayload payload;
    try {
      payload = decodeEfaFitTextPayload(text);
    } on EfaFitFormatException catch (error) {
      if (error.code == EfaFitFormatErrorCode.unsupportedVersion) {
        throw const FitTextImportException(FitTextImportErrorCode.unsupportedNativeVersion);
      }
      throw const FitTextImportException(FitTextImportErrorCode.invalidNativePayload);
    }

    try {
      return decodeNativeFitPayload(payload.json).fit;
    } on FitPersistenceException catch (error) {
      if (error.code == FitPersistenceErrorCode.unsupportedVersion) {
        throw const FitTextImportException(FitTextImportErrorCode.unsupportedNativeVersion);
      }
      throw const FitTextImportException(FitTextImportErrorCode.invalidNativePayload);
    }
  }

  Future<FitStorage> _parseEft(String text) async {
    final index = await _FitTypeNameIndex.load(ref);
    final collection = ref.read(repoCollectionProvider);
    final resolver = _EftTypeResolver(collection: collection, index: index);

    final EftFit parsed;
    try {
      parsed = parseEft(text, resolver: resolver);
    } on EftFormatException catch (error) {
      throw switch (error.code) {
        EftFormatErrorCode.unknownType => FitTextImportException(
          FitTextImportErrorCode.unknownType,
          detail: error.detail,
        ),
        EftFormatErrorCode.unavailableShip => FitTextImportException(
          FitTextImportErrorCode.unavailableShip,
          detail: error.detail,
        ),
        EftFormatErrorCode.invalid => const FitTextImportException(
          FitTextImportErrorCode.invalidEft,
        ),
      };
    }

    final ship = collection?.getShip(parsed.shipTypeId);
    if (ship == null) {
      throw FitTextImportException(FitTextImportErrorCode.unavailableShip, detail: parsed.name);
    }

    var fit = FitStorage.empty(
      FitMetadata(
        fitId: "import-preview",
        shipTypeId: parsed.shipTypeId,
        name: parsed.name,
        lastModified: 0,
        description: "",
        checkoutRef: const CheckoutRef(checkoutId: "", serverId: ""),
      ),
      ship,
    );

    for (final rack in EftRack.values) {
      final modules = parsed.racks[rack];
      if (modules == null) continue;
      for (var slotIndex = 0; slotIndex < modules.length; slotIndex++) {
        final module = modules[slotIndex];
        if (module == null) continue;
        fit = _setModuleAt(
          fit,
          rack,
          slotIndex,
          FitModuleItem(
            itemId: FitStorageItemId.item(id: module.typeId),
            state: module.online ? FitItemState.online : FitItemState.passive,
            charge: optionOf(module.chargeTypeId).map((id) => FitChargeItem(typeId: id)),
          ),
        );
      }
    }

    return fit.copyWith(
      body: fit.body.copyWith(
        drones: [
          for (final drone in parsed.drones)
            FitDroneItem(
              itemId: FitStorageItemId.item(id: drone.typeId),
              state: FitItemState.passive,
              quantity: drone.quantity,
            ),
        ].toIList(),
        fighters: [
          for (final (groupIndex, fighter) in parsed.fighters.indexed)
            FitFighterItem(
              itemId: FitStorageItemId.item(id: fighter.typeId),
              groupId: groupIndex,
              quantity: fighter.quantity,
              fighterAbility: 0,
            ),
        ].toIList(),
        implants: [
          for (final typeId in parsed.implants)
            FitImplantItem(
              itemId: FitStorageItemId.item(id: typeId),
              state: FitItemState.online,
            ),
        ].toIList(),
        boosters: [
          for (final booster in parsed.boosters)
            FitBoosterItem(
              itemId: FitStorageItemId.item(id: booster.typeId),
              index: booster.slotIndex,
              state: FitItemState.online,
            ),
        ].toIList(),
      ),
    );
  }

  FitStorage _setModuleAt(FitStorage fit, EftRack rack, int index, FitModuleItem module) {
    IList<Option<FitModuleItem>> updateList(IList<Option<FitModuleItem>> slots) {
      if (index < 0 || index >= slots.length) {
        throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
      }
      return slots.replace(index, some(module));
    }

    return switch (rack) {
      EftRack.low => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(low: updateList(fit.body.slots.low)),
        ),
      ),
      EftRack.medium => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(medium: updateList(fit.body.slots.medium)),
        ),
      ),
      EftRack.high => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(high: updateList(fit.body.slots.high)),
        ),
      ),
      EftRack.rig => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(rig: updateList(fit.body.slots.rig)),
        ),
      ),
      EftRack.subsystem => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(subsystem: updateList(fit.body.slots.subsystem)),
        ),
      ),
      EftRack.service => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(service: updateList(fit.body.slots.service)),
        ),
      ),
    };
  }
}

class _EftTypeResolver implements EftTypeResolver {
  const _EftTypeResolver({required this.collection, required this.index});

  final RepoCollectionService? collection;
  final _FitTypeNameIndex index;

  @override
  int? resolveTypeId(String name) => index.resolve(name);

  @override
  int? resolveShipId(String name) => index.resolveShip(name);

  @override
  bool isShip(int typeId) => collection?.getShip(typeId) != null;

  @override
  EftRack? rackOf(int typeId) {
    final slotsInfo = _slots;
    if (slotsInfo.lowSlots.containsKey(typeId)) return EftRack.low;
    if (slotsInfo.mediumSlots.containsKey(typeId)) return EftRack.medium;
    if (slotsInfo.highSlots.containsKey(typeId)) return EftRack.high;
    if (slotsInfo.rigSlots.containsKey(typeId)) return EftRack.rig;
    if (slotsInfo.subsystemSlots.containsKey(typeId)) return EftRack.subsystem;
    if (slotsInfo.serviceSlots.containsKey(typeId)) return EftRack.service;
    return null;
  }

  @override
  int? implantSlotOf(int typeId) => _slots.implantSlots[typeId]?.slotIndex;

  @override
  int? boosterSlotOf(int typeId) => _slots.boosterSlots[typeId]?.slotIndex;

  @override
  bool isDrone(int typeId) {
    final type = collection?.getType(typeId);
    if (type == null) {
      throw const FitTextImportException(FitTextImportErrorCode.unavailableData);
    }
    return type.hasMarketGroupId() && type.marketGroupId == EveConstMarketGroupId.drone;
  }

  @override
  bool isFighter(int typeId) {
    final type = collection?.getType(typeId);
    if (type == null) {
      throw const FitTextImportException(FitTextImportErrorCode.unavailableData);
    }
    return EveConstGroupId.fighter.contains(type.groupId);
  }

  Slots get _slots {
    final slots = collection?.slots;
    if (slots == null) {
      throw const FitTextImportException(FitTextImportErrorCode.unavailableData);
    }
    return slots;
  }
}

class _FitTypeNameIndex {
  const _FitTypeNameIndex({required this.byName, required this.shipNames});

  final Map<String, int> byName;
  final Map<String, int> shipNames;

  static Future<_FitTypeNameIndex> load(WidgetRef ref) async {
    final collection = ref.read(repoCollectionProvider);
    final allTypes = collection?.getAllTypes() ?? const IList.empty();
    final locale = ref.watch(localeProvider).name;

    final localizationKeys = <int>[];
    for (final type in allTypes) {
      localizationKeys.add(type.typeName.id);
    }

    final service = await ref.read(localizationDbServiceProvider.future);
    final localizedNames = await service?.localizedNames(localizationKeys, locale) ?? const {};
    final englishNames = locale == "en"
        ? localizedNames
        : await service?.localizedNames(localizationKeys, "en") ?? const {};

    final names = <String, int>{};
    final shipNames = <String, int>{};
    void addName(Map<int, String> resolved, int localizationKey, int typeId) {
      final name = resolved[localizationKey];
      if (name == null || name.trim().isEmpty) return;
      final trimmed = name.trim();
      names.putIfAbsent(trimmed, () => typeId);
      if (collection?.getShip(typeId) != null) {
        shipNames.putIfAbsent(trimmed, () => typeId);
      }
    }

    for (final type in allTypes) {
      addName(localizedNames, type.typeName.id, type.typeId);
      addName(englishNames, type.typeName.id, type.typeId);
    }

    return _FitTypeNameIndex(byName: names, shipNames: shipNames);
  }

  int? resolve(String name) => byName[name.trim()];

  int? resolveShip(String name) => shipNames[name.trim()] ?? resolve(name);
}
