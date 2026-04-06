import "dart:convert";
import "dart:io";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/localizations.pb.dart" as pb_l10n;
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

class FitTextImportException implements Exception {
  const FitTextImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FitTextImporter {
  const FitTextImporter(this.ref);

  static const nativePrefixes = <String>["EFA:", "EFA2:"];
  static const nativePayloadVersions = <String, int>{"EFA:": 1, "EFA2:": 2};

  final WidgetRef ref;

  Future<FitMetadata> importText(String input) async {
    final fit = await parse(input);
    return ref.read(fitManagerProvider.notifier).importFit(fit);
  }

  Future<FitStorage> parse(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw const FitTextImportException("Empty import text");
    }

    if (nativePrefixes.any(text.startsWith)) {
      return _parseNative(text);
    }

    if (text.startsWith("[") && text.contains("]")) {
      return _parseEft(text);
    }

    throw const FitTextImportException("Unsupported fit import format");
  }

  FitStorage _parseNative(String text) {
    try {
      final prefix = nativePrefixes.firstWhere(text.startsWith);
      final version = nativePayloadVersions[prefix];
      if (version == null) {
        throw const FitTextImportException("Unsupported native fit payload version");
      }

      final encoded = text.substring(prefix.length).trim();
      final compressed = base64Decode(encoded);
      final jsonText = utf8.decode(const GZipDecoder().decodeBytes(compressed));
      final payload = jsonDecode(jsonText) as Map<String, dynamic>;
      if (payload["version"] != version) {
        throw const FitTextImportException("Unsupported native fit payload version");
      }

      final fitJson = payload["fit"];
      if (fitJson is! Map<String, dynamic>) {
        throw const FitTextImportException("Invalid native fit payload");
      }
      return FitStorage.fromJson(fitJson);
    } on FitTextImportException {
      rethrow;
    } on Object catch (_) {
      throw const FitTextImportException("Failed to decode native fit payload");
    }
  }

  Future<FitStorage> _parseEft(String text) async {
    final index = await _FitTypeNameIndex.load(ref);
    final lines = text.split("\n").map((line) => line.trim()).toList(growable: false);
    final headerIndex = lines.indexWhere((line) => line.isNotEmpty);
    if (headerIndex < 0) {
      throw const FitTextImportException("Empty EFT text");
    }

    final header = _parseHeader(lines[headerIndex]);
    final shipTypeId = index.resolveShip(header.$1);
    if (shipTypeId == null) {
      throw FitTextImportException("Unknown ship name: ${header.$1}");
    }

    final ship = ref.read(bundleCollectionGetShipProvider(shipTypeId));
    if (ship == null) {
      throw FitTextImportException("Ship $shipTypeId is not available in the current bundle");
    }

    final slotsInfo = ref.read(bundleCollectionGetSlotsProvider);
    if (slotsInfo == null) {
      throw const FitTextImportException("Slot metadata is not available");
    }

    var fit = FitStorage.empty(
      FitMetadata(
        fitId: "import-preview",
        shipTypeId: shipTypeId,
        name: header.$2,
        lastModified: 0,
        description: "",
        bundleId: "",
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
            throw FitTextImportException("Unknown item name: ${parsed.$1}");
          }
          final type = ref.read(bundleCollectionGetTypeProvider(typeId));
          if (type == null) {
            throw FitTextImportException("Unknown type id: $typeId");
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
          } else {
            drones.add(
              FitDroneItem(
                itemId: FitStorageItemId.item(id: typeId),
                state: FitItemState.passive,
                quantity: parsed.$2,
              ),
            );
          }
        }
        continue;
      }

      if (block.every((line) => !_isModuleLine(line) && !_isCountLine(line))) {
        for (final line in block) {
          final typeId = index.resolve(line);
          if (typeId == null) {
            throw FitTextImportException("Unknown item name: $line");
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

          throw FitTextImportException("Unsupported EFT line: $line");
        }
        continue;
      }

      throw FitTextImportException("Unsupported EFT block: ${block.join(" | ")}");
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
      throw const FitTextImportException("Invalid EFT header");
    }
    final content = line.substring(1, line.length - 1);
    final separator = content.indexOf(",");
    if (separator < 0) {
      throw const FitTextImportException("Invalid EFT header");
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
          throw FitTextImportException("Mixed EFT rack block: $line");
        }
        slotIndices[rack] = (slotIndices[rack] ?? 0) + 1;
        continue;
      }

      final parsed = _tryParseModuleLine(line);
      if (parsed == null) {
        throw FitTextImportException("Invalid EFT module line: $line");
      }
      final typeId = index.resolve(parsed.typeName);
      if (typeId == null) {
        throw FitTextImportException("Unknown module name: ${parsed.typeName}");
      }
      if (_rackForTypeId(typeId, slotsInfo) != rack) {
        throw FitTextImportException("Module does not fit expected rack: ${parsed.typeName}");
      }

      final chargeId = parsed.chargeName == null ? null : index.resolve(parsed.chargeName!);
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
        throw FitTextImportException("EFT module index out of range for ${rack.name}");
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

  bool _isModuleLine(String line) =>
      line.startsWith("[Empty ") || _tryParseModuleLine(line) != null;

  (String, int) _parseCountLine(String line) {
    final match = RegExp(r"^(.+?) x(\d+)$").firstMatch(line);
    if (match == null) {
      throw FitTextImportException("Invalid quantity line: $line");
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
    final allTypes = ref.read(bundleCollectionGetAllTypesProvider);
    pb_l10n.Localization? englishLocalization;
    final englishPath = ref.read(localizationPathProvider("en"));
    if (englishPath != null) {
      final file = File(englishPath);
      if (file.existsSync()) {
        englishLocalization = pb_l10n.Localization.fromBuffer(await file.readAsBytes());
      }
    }
    final names = <String, int>{};
    final shipNames = <String, int>{};

    for (final type in allTypes) {
      final localizationKey = type.typeName.id;
      final localizedName = ref.read(localizationProvider(localizationKey));
      if (localizedName != null && localizedName.trim().isNotEmpty) {
        names.putIfAbsent(localizedName.trim(), () => type.typeId);
        if (ref.read(bundleCollectionGetShipProvider(type.typeId)) != null) {
          shipNames.putIfAbsent(localizedName.trim(), () => type.typeId);
        }
      }

      final englishName = englishLocalization?.localizedStrings[localizationKey];
      if (englishName != null && englishName.trim().isNotEmpty) {
        names.putIfAbsent(englishName.trim(), () => type.typeId);
        if (ref.read(bundleCollectionGetShipProvider(type.typeId)) != null) {
          shipNames.putIfAbsent(englishName.trim(), () => type.typeId);
        }
      }
    }

    return _FitTypeNameIndex(byName: names, shipNames: shipNames);
  }

  int? resolve(String name) => byName[name.trim()];

  int? resolveShip(String name) => shipNames[name.trim()] ?? resolve(name);
}
