enum EftRack { low, medium, high, rig, subsystem, service }

class EftModule {
  const EftModule({required this.typeId, this.chargeTypeId, this.online = true});

  final int typeId;
  final int? chargeTypeId;
  final bool online;
}

class EftStack {
  const EftStack({required this.typeId, required this.quantity});

  final int typeId;
  final int quantity;
}

class EftSlottedItem {
  const EftSlottedItem({required this.typeId, required this.slotIndex});

  final int typeId;
  final int slotIndex;
}

class EftFit {
  const EftFit({
    required this.shipTypeId,
    required this.name,
    this.racks = const {},
    this.drones = const [],
    this.fighters = const [],
    this.implants = const [],
    this.boosters = const [],
  });

  final int shipTypeId;
  final String name;
  final Map<EftRack, List<EftModule?>> racks;
  final List<EftStack> drones;
  final List<EftStack> fighters;
  final List<int> implants;
  final List<EftSlottedItem> boosters;
}

enum EftFormatErrorCode { invalid, unknownType, unavailableShip }

class EftFormatException implements Exception {
  const EftFormatException(this.code, {this.detail});

  final EftFormatErrorCode code;
  final String? detail;

  @override
  String toString() => "EftFormatException($code, detail: $detail)";
}

typedef EftTypeNameLookup = String? Function(int typeId);

abstract interface class EftTypeResolver {
  int? resolveTypeId(String name);
  int? resolveShipId(String name);
  bool isShip(int typeId);
  EftRack? rackOf(int typeId);
  int? implantSlotOf(int typeId);
  int? boosterSlotOf(int typeId);
  bool isDrone(int typeId);
  bool isFighter(int typeId);
}

const Map<EftRack, String> _rackPlaceholders = {
  EftRack.low: "[Empty Low slot]",
  EftRack.medium: "[Empty Med slot]",
  EftRack.high: "[Empty High slot]",
  EftRack.rig: "[Empty Rig slot]",
  EftRack.subsystem: "[Empty Subsystem slot]",
  EftRack.service: "[Empty Service slot]",
};

final RegExp _countLinePattern = RegExp(r"^.+ x\d+$");
final RegExp _countLineParse = RegExp(r"^(.+?) x(\d+)$");
final RegExp _moduleLinePattern = RegExp(
  r"^(?<type>[^,/\[\]]+?)(,\s*(?<charge>[^,/\[\]]+?))?(?<offline>\s*/offline)?$",
  caseSensitive: false,
);

EftFit parseEft(String text, {required EftTypeResolver resolver}) {
  final lines = text.split("\n").map((line) => line.trim()).toList(growable: false);
  final headerIndex = lines.indexWhere((line) => line.isNotEmpty);
  if (headerIndex < 0) {
    throw const EftFormatException(EftFormatErrorCode.invalid);
  }

  final header = _parseHeader(lines[headerIndex]);
  final shipTypeId = resolver.resolveShipId(header.$1);
  if (shipTypeId == null) {
    throw EftFormatException(EftFormatErrorCode.unknownType, detail: header.$1);
  }
  if (!resolver.isShip(shipTypeId)) {
    throw EftFormatException(EftFormatErrorCode.unavailableShip, detail: header.$1);
  }

  final racks = <EftRack, List<EftModule?>>{};
  final implants = <EftSlottedItem>[];
  final boosters = <EftSlottedItem>[];
  final drones = <EftStack>[];
  final fighters = <EftStack>[];

  for (final block in _splitBlocks(lines.skip(headerIndex + 1))) {
    final rack = _detectRack(block, resolver);
    if (rack != null) {
      _applyRackBlock(racks, rack, block, resolver);
      continue;
    }

    if (block.every(_isCountLine)) {
      for (final line in block) {
        final parsed = _parseCountLine(line);
        final typeId = resolver.resolveTypeId(parsed.$1);
        if (typeId == null) {
          throw EftFormatException(EftFormatErrorCode.unknownType, detail: parsed.$1);
        }
        if (resolver.isFighter(typeId)) {
          fighters.add(EftStack(typeId: typeId, quantity: parsed.$2));
          continue;
        }
        if (resolver.isDrone(typeId)) {
          drones.add(EftStack(typeId: typeId, quantity: parsed.$2));
          continue;
        }
        throw const EftFormatException(EftFormatErrorCode.invalid);
      }
      continue;
    }

    if (_isCharacterBlock(block, resolver)) {
      for (final line in block) {
        final typeId = resolver.resolveTypeId(line);
        if (typeId == null) {
          throw EftFormatException(EftFormatErrorCode.unknownType, detail: line);
        }
        final implantSlot = resolver.implantSlotOf(typeId);
        if (implantSlot != null) {
          implants.add(EftSlottedItem(typeId: typeId, slotIndex: implantSlot));
          continue;
        }
        final boosterSlot = resolver.boosterSlotOf(typeId);
        if (boosterSlot != null) {
          boosters.add(EftSlottedItem(typeId: typeId, slotIndex: boosterSlot));
          continue;
        }
        throw const EftFormatException(EftFormatErrorCode.invalid);
      }
      continue;
    }

    throw const EftFormatException(EftFormatErrorCode.invalid);
  }

  implants.sort((left, right) => left.slotIndex.compareTo(right.slotIndex));
  boosters.sort((left, right) => left.slotIndex.compareTo(right.slotIndex));

  return EftFit(
    shipTypeId: shipTypeId,
    name: header.$2,
    racks: racks,
    drones: drones,
    fighters: fighters,
    implants: [for (final item in implants) item.typeId],
    boosters: boosters,
  );
}

String formatEft(EftFit fit, {required EftTypeNameLookup typeName}) {
  String nameOf(int typeId) => typeName(typeId) ?? "Unknown Type[$typeId]";

  final sections = <String>[];

  final moduleSection = <String>[];
  for (final rack in EftRack.values) {
    final slots = fit.racks[rack];
    if (slots == null || slots.isEmpty) continue;

    final lines = <String>[
      for (final slot in slots)
        if (slot == null) _rackPlaceholders[rack]! else _formatModuleLine(slot, nameOf),
    ];
    if (lines.isNotEmpty) {
      moduleSection.add(lines.join("\n"));
    }
  }
  if (moduleSection.isNotEmpty) {
    sections.add(moduleSection.join("\n\n"));
  }

  final minionSection = <String>[];
  if (fit.drones.isNotEmpty) {
    minionSection.add(
      fit.drones.map((drone) => "${nameOf(drone.typeId)} x${drone.quantity}").join("\n"),
    );
  }
  if (fit.fighters.isNotEmpty) {
    minionSection.add(
      fit.fighters.map((fighter) => "${nameOf(fighter.typeId)} x${fighter.quantity}").join("\n"),
    );
  }
  if (minionSection.isNotEmpty) {
    sections.add(minionSection.join("\n\n"));
  }

  final characterSection = <String>[];
  if (fit.implants.isNotEmpty) {
    characterSection.add(fit.implants.map(nameOf).join("\n"));
  }
  if (fit.boosters.isNotEmpty) {
    characterSection.add(fit.boosters.map((booster) => nameOf(booster.typeId)).join("\n"));
  }
  if (characterSection.isNotEmpty) {
    sections.add(characterSection.join("\n\n"));
  }

  final header = "[${nameOf(fit.shipTypeId)}, ${fit.name}]";
  if (sections.isEmpty) {
    return "$header\n";
  }
  return "$header\n\n${sections.join("\n\n\n")}";
}

String _formatModuleLine(EftModule module, String Function(int typeId) nameOf) {
  final chargeSuffix = module.chargeTypeId == null ? "" : ", ${nameOf(module.chargeTypeId!)}";
  final offlineSuffix = module.online ? "" : " /offline";
  return "${nameOf(module.typeId)}$chargeSuffix$offlineSuffix";
}

(String, String) _parseHeader(String line) {
  if (!line.startsWith("[") || !line.endsWith("]")) {
    throw const EftFormatException(EftFormatErrorCode.invalid);
  }
  final content = line.substring(1, line.length - 1);
  final separator = content.indexOf(",");
  if (separator < 0) {
    throw const EftFormatException(EftFormatErrorCode.invalid);
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

EftRack? _detectRack(List<String> block, EftTypeResolver resolver) {
  for (final line in block) {
    final placeholderRack = _placeholderRack(line);
    if (placeholderRack != null) {
      return placeholderRack;
    }

    final parsed = _tryParseModuleLine(line);
    if (parsed == null) continue;
    final typeId = resolver.resolveTypeId(parsed.typeName);
    if (typeId == null) continue;
    return resolver.rackOf(typeId);
  }
  return null;
}

void _applyRackBlock(
  Map<EftRack, List<EftModule?>> racks,
  EftRack rack,
  List<String> block,
  EftTypeResolver resolver,
) {
  final slots = racks.putIfAbsent(rack, () => <EftModule?>[]);
  for (final line in block) {
    final placeholderRack = _placeholderRack(line);
    if (placeholderRack != null) {
      if (placeholderRack != rack) {
        throw const EftFormatException(EftFormatErrorCode.invalid);
      }
      slots.add(null);
      continue;
    }

    final parsed = _tryParseModuleLine(line);
    if (parsed == null) {
      throw const EftFormatException(EftFormatErrorCode.invalid);
    }
    final typeId = resolver.resolveTypeId(parsed.typeName);
    if (typeId == null) {
      throw EftFormatException(EftFormatErrorCode.unknownType, detail: parsed.typeName);
    }
    if (resolver.rackOf(typeId) != rack) {
      throw const EftFormatException(EftFormatErrorCode.invalid);
    }

    final chargeId = parsed.chargeName == null ? null : resolver.resolveTypeId(parsed.chargeName!);
    if (parsed.chargeName != null && chargeId == null) {
      throw EftFormatException(EftFormatErrorCode.unknownType, detail: parsed.chargeName);
    }

    slots.add(EftModule(typeId: typeId, chargeTypeId: chargeId, online: !parsed.offline));
  }
}

bool _isCountLine(String line) => _countLinePattern.hasMatch(line);

bool _isCharacterBlock(List<String> block, EftTypeResolver resolver) {
  for (final line in block) {
    if (_isCountLine(line) || line.startsWith("[Empty ")) {
      return false;
    }

    final parsed = _tryParseModuleLine(line);
    if (parsed == null || parsed.chargeName != null || parsed.offline) {
      return false;
    }

    final typeId = resolver.resolveTypeId(parsed.typeName);
    if (typeId == null) {
      return false;
    }

    if (resolver.implantSlotOf(typeId) == null && resolver.boosterSlotOf(typeId) == null) {
      return false;
    }
  }

  return block.isNotEmpty;
}

(String, int) _parseCountLine(String line) {
  final match = _countLineParse.firstMatch(line);
  if (match == null) {
    throw const EftFormatException(EftFormatErrorCode.invalid);
  }
  return (match.group(1)!.trim(), int.parse(match.group(2)!));
}

_ParsedModuleLine? _tryParseModuleLine(String line) {
  final match = _moduleLinePattern.firstMatch(line);
  if (match == null) {
    return null;
  }
  return _ParsedModuleLine(
    typeName: match.namedGroup("type")!.trim(),
    chargeName: match.namedGroup("charge")?.trim(),
    offline: match.namedGroup("offline") != null,
  );
}

EftRack? _placeholderRack(String line) {
  for (final entry in _rackPlaceholders.entries) {
    if (entry.value == line) return entry.key;
  }
  return null;
}

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
