import "dart:convert";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
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
  static const _legacyNativePrefixVersion = 1;
  static const _currentNativePrefixVersion = 2;

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
    try {
      final prefixMatch = _nativePrefixPattern.matchAsPrefix(text);
      if (prefixMatch == null) {
        throw const FitTextImportException(FitTextImportErrorCode.unsupportedNativeVersion);
      }
      final explicitVersion = prefixMatch.group(1);
      final prefixVersion = explicitVersion == null
          ? _legacyNativePrefixVersion
          : int.tryParse(explicitVersion);
      if (prefixVersion == null ||
          prefixVersion < _legacyNativePrefixVersion ||
          prefixVersion > _currentNativePrefixVersion) {
        throw const FitTextImportException(FitTextImportErrorCode.unsupportedNativeVersion);
      }

      final encoded = text.substring(prefixMatch.end).trim();
      final compressed = base64Decode(encoded);
      final jsonText = utf8.decode(const GZipDecoder().decodeBytes(compressed));
      final payload = jsonDecode(jsonText) as Map<String, dynamic>;
      try {
        return decodeNativeFitPayload(payload).fit;
      } on FitPersistenceException catch (error) {
        if (error.code == FitPersistenceErrorCode.unsupportedVersion) {
          throw const FitTextImportException(FitTextImportErrorCode.unsupportedNativeVersion);
        }
        throw const FitTextImportException(FitTextImportErrorCode.invalidNativePayload);
      }
    } on FitTextImportException {
      rethrow;
    } on Object catch (_) {
      throw const FitTextImportException(FitTextImportErrorCode.invalidNativePayload);
    }
  }

  Future<FitStorage> _parseEft(String text) async {
    final index = await _FitTypeNameIndex.load(ref);
    final lines = text.split("\n").map((line) => line.trim()).toList(growable: false);
    final headerIndex = lines.indexWhere((line) => line.isNotEmpty);
    if (headerIndex < 0) {
      throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
    }

    final header = _parseHeader(lines[headerIndex]);
    final shipTypeId = index.resolveShip(header.$1);
    if (shipTypeId == null) {
      throw FitTextImportException(FitTextImportErrorCode.unknownType, detail: header.$1);
    }

    final ship = ref.read(repoCollectionProvider)?.getShip(shipTypeId);
    if (ship == null) {
      throw FitTextImportException(FitTextImportErrorCode.unavailableShip, detail: header.$1);
    }

    final slotsInfo = ref.read(repoCollectionProvider)?.slots;
    if (slotsInfo == null) {
      throw const FitTextImportException(FitTextImportErrorCode.unavailableData);
    }

    var fit = FitStorage.empty(
      FitMetadata(
        fitId: "import-preview",
        shipTypeId: shipTypeId,
        name: header.$2,
        lastModified: 0,
        description: "",
        checkoutRef: const CheckoutRef(checkoutId: "", serverId: ""),
      ),
      ship,
    );

    final blocks = _splitBlocks(lines.skip(headerIndex + 1));
    final slotIndices = <_ModuleRack, int>{for (final rack in _ModuleRack.values) rack: 0};
    final implants = <(int slot, FitImplantItem item)>[];
    final boosters = <(int slot, FitBoosterItem item)>[];
    final drones = <FitDroneItem>[];
    final fighters = <FitFighterItem>[];

    for (final block in blocks) {
      final rack = _detectRack(block, index, slotsInfo);
      if (rack != null) {
        fit = _applyRackBlock(fit, rack, block, slotIndices, index, slotsInfo);
        continue;
      }

      if (block.every(_isCountLine)) {
        for (final line in block) {
          final parsed = _parseCountLine(line);
          final typeId = index.resolve(parsed.$1);
          if (typeId == null) {
            throw FitTextImportException(FitTextImportErrorCode.unknownType, detail: parsed.$1);
          }
          final type = ref.read(repoCollectionProvider)?.getType(typeId);
          if (type == null) {
            throw const FitTextImportException(FitTextImportErrorCode.unavailableData);
          }

          if (EveConstGroupId.fighter.contains(type.groupId)) {
            fighters.add(
              FitFighterItem(
                itemId: FitStorageItemId.item(id: typeId),
                groupId: fighters.length,
                quantity: parsed.$2,
                fighterAbility: 0,
              ),
            );
            continue;
          }

          if (type.hasMarketGroupId() && type.marketGroupId == EveConstMarketGroupId.drone) {
            drones.add(
              FitDroneItem(
                itemId: FitStorageItemId.item(id: typeId),
                state: FitItemState.passive,
                quantity: parsed.$2,
              ),
            );
            continue;
          }

          throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
        }
        continue;
      }

      if (_isCharacterBlock(block, index, slotsInfo)) {
        for (final line in block) {
          final typeId = index.resolve(line);
          if (typeId == null) {
            throw FitTextImportException(FitTextImportErrorCode.unknownType, detail: line);
          }
          final implantSlot = slotsInfo.implantSlots[typeId]?.slotIndex;
          if (implantSlot != null) {
            implants.add((
              implantSlot,
              FitImplantItem(
                itemId: FitStorageItemId.item(id: typeId),
                state: FitItemState.online,
              ),
            ));
            continue;
          }

          final boosterSlot = slotsInfo.boosterSlots[typeId]?.slotIndex;
          if (boosterSlot != null) {
            boosters.add((
              boosterSlot,
              FitBoosterItem(
                itemId: FitStorageItemId.item(id: typeId),
                index: boosterSlot,
                state: FitItemState.online,
              ),
            ));
            continue;
          }

          throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
        }
        continue;
      }

      throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
    }

    implants.sort((left, right) => left.$1.compareTo(right.$1));
    boosters.sort((left, right) => left.$1.compareTo(right.$1));

    return fit.copyWith(
      body: fit.body.copyWith(
        drones: drones.toIList(),
        fighters: fighters.toIList(),
        implants: implants.map((entry) => entry.$2).toIList(),
        boosters: boosters.map((entry) => entry.$2).toIList(),
      ),
    );
  }

  (String, String) _parseHeader(String line) {
    if (!line.startsWith("[") || !line.endsWith("]")) {
      throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
    }
    final content = line.substring(1, line.length - 1);
    final separator = content.indexOf(",");
    if (separator < 0) {
      throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
    }
    return (content.substring(0, separator).trim(), content.substring(separator + 1).trim());
  }

  List<List<String>> _splitBlocks(Iterable<String> lines) {
    final blocks = <List<String>>[];
    var current = <String>[];
    for (final line in lines) {
      if (line.trim().isEmpty) {
        if (current.isNotEmpty) {
          blocks.add(current);
          current = <String>[];
        }
        continue;
      }
      current.add(line);
    }
    if (current.isNotEmpty) {
      blocks.add(current);
    }
    return blocks;
  }

  _ModuleRack? _detectRack(List<String> block, _FitTypeNameIndex index, Slots slotsInfo) {
    for (final line in block) {
      final placeholderRack = _placeholderRack(line);
      if (placeholderRack != null) {
        return placeholderRack;
      }

      final parsed = _tryParseModuleLine(line);
      if (parsed == null) continue;
      final typeId = index.resolve(parsed.typeName);
      if (typeId == null) continue;
      return _rackForTypeId(typeId, slotsInfo);
    }
    return null;
  }

  FitStorage _applyRackBlock(
    FitStorage fit,
    _ModuleRack rack,
    List<String> block,
    Map<_ModuleRack, int> slotIndices,
    _FitTypeNameIndex index,
    Slots slotsInfo,
  ) {
    var currentFit = fit;
    for (final line in block) {
      final placeholderRack = _placeholderRack(line);
      if (placeholderRack != null) {
        if (placeholderRack != rack) {
          throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
        }
        slotIndices[rack] = (slotIndices[rack] ?? 0) + 1;
        continue;
      }

      final parsed = _tryParseModuleLine(line);
      if (parsed == null) {
        throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
      }
      final typeId = index.resolve(parsed.typeName);
      if (typeId == null) {
        throw FitTextImportException(FitTextImportErrorCode.unknownType, detail: parsed.typeName);
      }
      if (_rackForTypeId(typeId, slotsInfo) != rack) {
        throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
      }

      final chargeId = parsed.chargeName == null ? null : index.resolve(parsed.chargeName!);
      if (parsed.chargeName != null && chargeId == null) {
        throw FitTextImportException(FitTextImportErrorCode.unknownType, detail: parsed.chargeName);
      }

      final nextIndex = slotIndices[rack] ?? 0;
      currentFit = _setModuleAt(
        currentFit,
        rack,
        nextIndex,
        FitModuleItem(
          itemId: FitStorageItemId.item(id: typeId),
          state: parsed.offline ? FitItemState.passive : FitItemState.online,
          charge: optionOf(chargeId).map((id) => FitChargeItem(typeId: id)),
        ),
      );
      slotIndices[rack] = nextIndex + 1;
    }
    return currentFit;
  }

  FitStorage _setModuleAt(FitStorage fit, _ModuleRack rack, int index, FitModuleItem module) {
    IList<Option<FitModuleItem>> updateList(IList<Option<FitModuleItem>> slots) {
      if (index < 0 || index >= slots.length) {
        throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
      }
      return slots.replace(index, some(module));
    }

    return switch (rack) {
      _ModuleRack.low => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(low: updateList(fit.body.slots.low)),
        ),
      ),
      _ModuleRack.medium => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(medium: updateList(fit.body.slots.medium)),
        ),
      ),
      _ModuleRack.high => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(high: updateList(fit.body.slots.high)),
        ),
      ),
      _ModuleRack.rig => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(rig: updateList(fit.body.slots.rig)),
        ),
      ),
      _ModuleRack.subsystem => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(subsystem: updateList(fit.body.slots.subsystem)),
        ),
      ),
      _ModuleRack.service => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(service: updateList(fit.body.slots.service)),
        ),
      ),
    };
  }

  bool _isCountLine(String line) => RegExp(r"^.+ x\d+$").hasMatch(line);

  bool _isCharacterBlock(List<String> block, _FitTypeNameIndex index, Slots slotsInfo) {
    for (final line in block) {
      if (_isCountLine(line) || line.startsWith("[Empty ")) {
        return false;
      }

      final parsed = _tryParseModuleLine(line);
      if (parsed == null || parsed.chargeName != null || parsed.offline) {
        return false;
      }

      final typeId = index.resolve(parsed.typeName);
      if (typeId == null) {
        return false;
      }

      if (!slotsInfo.implantSlots.containsKey(typeId) &&
          !slotsInfo.boosterSlots.containsKey(typeId)) {
        return false;
      }
    }

    return block.isNotEmpty;
  }

  (String, int) _parseCountLine(String line) {
    final match = RegExp(r"^(.+?) x(\d+)$").firstMatch(line);
    if (match == null) {
      throw const FitTextImportException(FitTextImportErrorCode.invalidEft);
    }
    return (match.group(1)!.trim(), int.parse(match.group(2)!));
  }

  _ParsedModuleLine? _tryParseModuleLine(String line) {
    final match = RegExp(
      r"^(?<type>[^,/\[\]]+?)(,\s*(?<charge>[^,/\[\]]+?))?(?<offline>\s*/(OFFLINE|offline))?$",
    ).firstMatch(line);
    if (match == null) {
      return null;
    }
    return _ParsedModuleLine(
      typeName: match.namedGroup("type")!.trim(),
      chargeName: match.namedGroup("charge")?.trim(),
      offline: match.namedGroup("offline") != null,
    );
  }

  _ModuleRack? _placeholderRack(String line) => switch (line) {
    "[Empty Low slot]" => _ModuleRack.low,
    "[Empty Med slot]" => _ModuleRack.medium,
    "[Empty High slot]" => _ModuleRack.high,
    "[Empty Rig slot]" => _ModuleRack.rig,
    "[Empty Subsystem slot]" => _ModuleRack.subsystem,
    "[Empty Service slot]" => _ModuleRack.service,
    _ => null,
  };

  _ModuleRack? _rackForTypeId(int typeId, Slots slotsInfo) {
    if (slotsInfo.lowSlots.containsKey(typeId)) return _ModuleRack.low;
    if (slotsInfo.mediumSlots.containsKey(typeId)) return _ModuleRack.medium;
    if (slotsInfo.highSlots.containsKey(typeId)) return _ModuleRack.high;
    if (slotsInfo.rigSlots.containsKey(typeId)) return _ModuleRack.rig;
    if (slotsInfo.subsystemSlots.containsKey(typeId)) return _ModuleRack.subsystem;
    if (slotsInfo.serviceSlots.containsKey(typeId)) return _ModuleRack.service;
    return null;
  }
}

enum _ModuleRack { low, medium, high, rig, subsystem, service }

class _ParsedModuleLine {
  const _ParsedModuleLine({
    required this.typeName,
    required this.chargeName,
    required this.offline,
  });

  final String typeName;
  final String? chargeName;
  final bool offline;
}

class _FitTypeNameIndex {
  const _FitTypeNameIndex({required this.byName, required this.shipNames});

  final Map<String, int> byName;
  final Map<String, int> shipNames;

  static Future<_FitTypeNameIndex> load(WidgetRef ref) async {
    final allTypes = ref.read(repoCollectionProvider)?.getAllTypes() ?? const IList.empty();
    final locale = ref.watch(localeProvider).name;
    final names = <String, int>{};
    final shipNames = <String, int>{};

    for (final type in allTypes) {
      final localizationKey = type.typeName.id;
      final localizedName = ref
          .read(repoCollectionProvider)
          ?.getLocalizedName(localizationKey, locale);
      if (localizedName != null && localizedName.trim().isNotEmpty) {
        names.putIfAbsent(localizedName.trim(), () => type.typeId);
        if (ref.read(repoCollectionProvider)?.getShip(type.typeId) != null) {
          shipNames.putIfAbsent(localizedName.trim(), () => type.typeId);
        }
      }

      final englishName = ref.read(repoCollectionProvider)?.getLocalizedName(localizationKey, "en");
      if (englishName != null && englishName.trim().isNotEmpty) {
        names.putIfAbsent(englishName.trim(), () => type.typeId);
        if (ref.read(repoCollectionProvider)?.getShip(type.typeId) != null) {
          shipNames.putIfAbsent(englishName.trim(), () => type.typeId);
        }
      }
    }

    return _FitTypeNameIndex(byName: names, shipNames: shipNames);
  }

  int? resolve(String name) => byName[name.trim()];

  int? resolveShip(String name) => shipNames[name.trim()] ?? resolve(name);
}
