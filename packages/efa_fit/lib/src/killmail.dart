import "dart:convert";

enum KillmailRack { low, medium, high, rig, subsystem, service }

class KillmailItem {
  const KillmailItem({
    required this.flag,
    required this.typeId,
    this.quantityDropped = 0,
    this.quantityDestroyed = 0,
  });

  final int flag;
  final int typeId;
  final int quantityDropped;
  final int quantityDestroyed;

  int get quantity => quantityDropped + quantityDestroyed;
}

class Killmail {
  const Killmail({
    required this.killmailId,
    required this.shipTypeId,
    this.killmailTime,
    this.items = const [],
  });

  final int killmailId;
  final int shipTypeId;
  final DateTime? killmailTime;
  final List<KillmailItem> items;
}

class KillmailStack {
  const KillmailStack({required this.typeId, required this.quantity});

  final int typeId;
  final int quantity;
}

class KillmailFit {
  const KillmailFit({
    required this.killmailId,
    required this.shipTypeId,
    this.killmailTime,
    this.racks = const {},
    this.drones = const [],
    this.fighters = const [],
    this.skippedTypeIds = const [],
  });

  final int killmailId;
  final int shipTypeId;
  final DateTime? killmailTime;

  /// Candidate type IDs per module slot. ESI lists loaded charges as ordinary
  /// items reusing the module's flag, so a rack/index can hold more than one
  /// candidate; importers resolve the module against static slot data and
  /// treat the remaining candidates as charges.
  final Map<KillmailRack, Map<int, List<int>>> racks;
  final List<KillmailStack> drones;
  final List<KillmailStack> fighters;
  final List<int> skippedTypeIds;
}

enum KillmailFormatErrorCode { invalid }

class KillmailFormatException implements Exception {
  const KillmailFormatException(this.code, {this.detail});

  final KillmailFormatErrorCode code;
  final String? detail;

  @override
  String toString() => "KillmailFormatException($code, detail: $detail)";
}

// ESI inventory flag ranges relevant to fitting reconstruction.
const int _flagCargo = 5;
const int _flagDroneBay = 87;
const int _flagFighterBay = 155;
const int _flagFighterTubeFirst = 159;
const int _flagFighterTubeLast = 163;
const int _flagLoSlotFirst = 11;
const int _flagLoSlotLast = 18;
const int _flagMedSlotFirst = 19;
const int _flagMedSlotLast = 26;
const int _flagHiSlotFirst = 27;
const int _flagHiSlotLast = 34;
const int _flagRigSlotFirst = 92;
const int _flagRigSlotLast = 99;
const int _flagSubSystemSlotFirst = 125;
const int _flagSubSystemSlotLast = 132;
const int _flagServiceSlotFirst = 164;
const int _flagServiceSlotLast = 171;

/// Maps an ESI inventory flag to a module rack and slot index. Returns `null`
/// for flags that do not address a module slot (cargo, bays, holds, ...).
(KillmailRack, int)? killmailFlagToRack(int flag) => switch (flag) {
  >= _flagLoSlotFirst && <= _flagLoSlotLast => (KillmailRack.low, flag - _flagLoSlotFirst),
  >= _flagMedSlotFirst && <= _flagMedSlotLast => (KillmailRack.medium, flag - _flagMedSlotFirst),
  >= _flagHiSlotFirst && <= _flagHiSlotLast => (KillmailRack.high, flag - _flagHiSlotFirst),
  >= _flagRigSlotFirst && <= _flagRigSlotLast => (KillmailRack.rig, flag - _flagRigSlotFirst),
  >= _flagSubSystemSlotFirst && <= _flagSubSystemSlotLast => (
    KillmailRack.subsystem,
    flag - _flagSubSystemSlotFirst,
  ),
  >= _flagServiceSlotFirst && <= _flagServiceSlotLast => (
    KillmailRack.service,
    flag - _flagServiceSlotFirst,
  ),
  _ => null,
};

bool _isDroneBayFlag(int flag) => flag == _flagDroneBay;

bool _isFighterFlag(int flag) =>
    flag == _flagFighterBay || (flag >= _flagFighterTubeFirst && flag <= _flagFighterTubeLast);

Killmail parseKillmailJson(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const KillmailFormatException(KillmailFormatErrorCode.invalid);
  }

  Map<String, dynamic>? payload;
  if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
    payload = decoded.first as Map<String, dynamic>;
  } else if (decoded is Map<String, dynamic>) {
    payload = decoded;
  }
  if (payload == null) {
    throw const KillmailFormatException(KillmailFormatErrorCode.invalid);
  }
  return killmailFromMap(payload);
}

Killmail killmailFromMap(Map<String, dynamic> payload) {
  final killmailId = payload["killmail_id"];
  final victim = payload["victim"];
  if (killmailId is! int || victim is! Map<String, dynamic>) {
    throw const KillmailFormatException(KillmailFormatErrorCode.invalid);
  }
  final shipTypeId = victim["ship_type_id"];
  if (shipTypeId is! int) {
    throw const KillmailFormatException(KillmailFormatErrorCode.invalid);
  }

  DateTime? killmailTime;
  final time = payload["killmail_time"];
  if (time is String) {
    killmailTime = DateTime.tryParse(time);
  }

  final rawItems = victim["items"];
  final items = <KillmailItem>[];
  if (rawItems is List) {
    for (final raw in rawItems) {
      final item = _parseItem(raw);
      if (item != null) items.add(item);
    }
  }

  return Killmail(
    killmailId: killmailId,
    shipTypeId: shipTypeId,
    killmailTime: killmailTime,
    items: items,
  );
}

KillmailItem? _parseItem(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final flag = raw["flag"];
  final typeId = raw["item_type_id"];
  if (flag is! int || typeId is! int) return null;
  final dropped = raw["quantity_dropped"];
  final destroyed = raw["quantity_destroyed"];
  return KillmailItem(
    flag: flag,
    typeId: typeId,
    quantityDropped: dropped is int ? dropped : 0,
    quantityDestroyed: destroyed is int ? destroyed : 0,
  );
}

/// Reconstructs the victim's fitting from a killmail. Cargo, ammo holds, and
/// any item with an unrecognized flag are dropped and reported through
/// [KillmailFit.skippedTypeIds]. ESI reports loaded charges as ordinary items
/// sharing the module's flag, so all same-flag candidates are preserved in
/// [KillmailFit.racks] for the importer to disambiguate. Killmails do not
/// record module online/offline state, so it is not reconstructed.
KillmailFit killmailToFit(Killmail killmail) {
  final racks = <KillmailRack, Map<int, List<int>>>{};
  final drones = <int, int>{};
  final fighters = <int, int>{};
  final skipped = <int>[];

  for (final item in killmail.items) {
    if (item.quantity <= 0) continue;

    final slot = killmailFlagToRack(item.flag);
    if (slot != null) {
      final (rack, index) = slot;
      racks.putIfAbsent(rack, () => {}).putIfAbsent(index, () => []).add(item.typeId);
      continue;
    }
    if (_isDroneBayFlag(item.flag)) {
      drones.update(item.typeId, (sum) => sum + item.quantity, ifAbsent: () => item.quantity);
      continue;
    }
    if (_isFighterFlag(item.flag)) {
      fighters.update(item.typeId, (sum) => sum + item.quantity, ifAbsent: () => item.quantity);
      continue;
    }
    if (item.flag != _flagCargo) {
      skipped.add(item.typeId);
    }
  }

  return KillmailFit(
    killmailId: killmail.killmailId,
    shipTypeId: killmail.shipTypeId,
    killmailTime: killmail.killmailTime,
    racks: racks,
    drones: [
      for (final entry in drones.entries) KillmailStack(typeId: entry.key, quantity: entry.value),
    ],
    fighters: [
      for (final entry in fighters.entries) KillmailStack(typeId: entry.key, quantity: entry.value),
    ],
    skippedTypeIds: skipped,
  );
}
