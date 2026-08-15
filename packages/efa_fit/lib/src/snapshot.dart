import "package:efa_proto/fit.pbenum.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:efa_proto/utils.pb.dart" as utils_pb;
import "package:fixnum/fixnum.dart";

export "package:efa_proto/fit.pbenum.dart"
    show Slots_SlotState, Subsystem_SubsystemType, TacticalMode_TacticalModeVariant;
export "package:efa_proto/fit_snapshot.pb.dart";

const int currentFitSnapshotVersion = 1;

const int implantSlotCount = 10;

enum SnapshotRack { high, medium, low, rig, service }

class FitSnapshotBuildException implements Exception {
  const FitSnapshotBuildException(this.message);

  final String message;

  @override
  String toString() => "FitSnapshotBuildException: $message";
}

class SnapshotIcon {
  const SnapshotIcon({this.graphicId, this.iconId});

  final int? graphicId;
  final int? iconId;
}

class SnapshotMetaGroupData {
  const SnapshotMetaGroupData({required this.id, this.names = const {}, this.icon});

  final int id;
  final Map<String, String> names;
  final SnapshotIcon? icon;
}

class SnapshotTypeData {
  const SnapshotTypeData({required this.typeId, required this.names, this.icon, this.metaGroup});

  final int typeId;
  final Map<String, String> names;
  final SnapshotIcon? icon;
  final SnapshotMetaGroupData? metaGroup;
}

class SnapshotDisplayValueData {
  const SnapshotDisplayValueData({required this.text, this.attributeId, this.icon});

  final String text;
  final int? attributeId;
  final SnapshotIcon? icon;
}

class SnapshotChargeData {
  const SnapshotChargeData({required this.type, this.quantity});

  final SnapshotTypeData type;
  final int? quantity;
}

class SnapshotModuleData {
  const SnapshotModuleData({
    required this.type,
    this.state = Slots_SlotState.PASSIVE,
    this.charge,
    this.isTurret = false,
    this.isLauncher = false,
    this.originType,
    this.relatedValues = const [],
  });

  final SnapshotTypeData type;
  final Slots_SlotState state;
  final SnapshotChargeData? charge;
  final bool isTurret;
  final bool isLauncher;
  final SnapshotTypeData? originType;
  final List<SnapshotDisplayValueData> relatedValues;
}

class SnapshotDroneData {
  const SnapshotDroneData({
    required this.type,
    required this.quantity,
    this.state = Slots_SlotState.PASSIVE,
  });

  final SnapshotTypeData type;
  final Slots_SlotState state;
  final int quantity;
}

class SnapshotFighterData {
  const SnapshotFighterData({
    required this.type,
    required this.quantity,
    required this.maxSquadronSize,
    required this.group,
    this.state = Slots_SlotState.PASSIVE,
    this.abilities = const [],
    this.relatedValues = const [],
  });

  final SnapshotTypeData type;
  final Slots_SlotState state;
  final int quantity;
  final int maxSquadronSize;
  final SnapshotFighter_SquadronGroup group;
  final List<SnapshotFighter_Ability> abilities;
  final List<SnapshotDisplayValueData> relatedValues;
}

class SnapshotBoosterData {
  const SnapshotBoosterData({
    required this.slotIndex,
    required this.type,
    this.state = Slots_SlotState.PASSIVE,
  });

  final int slotIndex;
  final SnapshotTypeData type;
  final Slots_SlotState state;
}

class SnapshotTacticalModeData {
  const SnapshotTacticalModeData({required this.type, required this.variant});

  final SnapshotTypeData type;
  final TacticalMode_TacticalModeVariant variant;
}

class SnapshotShipLayoutData {
  const SnapshotShipLayoutData({
    this.highSlots = 0,
    this.mediumSlots = 0,
    this.lowSlots = 0,
    this.rigSlots = 0,
    this.subsystemSlots = 0,
    this.serviceSlots = 0,
    this.turretHardpoints = 0,
    this.launcherHardpoints = 0,
    this.fighterTubes = 0,
  });

  final int highSlots;
  final int mediumSlots;
  final int lowSlots;
  final int rigSlots;
  final int subsystemSlots;
  final int serviceSlots;
  final int turretHardpoints;
  final int launcherHardpoints;
  final int fighterTubes;
}

class SnapshotDamageProfile {
  const SnapshotDamageProfile({
    required this.em,
    required this.thermal,
    required this.kinetic,
    required this.explosive,
  });

  const SnapshotDamageProfile.uniform([double value = 0.25])
    : em = value,
      thermal = value,
      kinetic = value,
      explosive = value;

  final double em;
  final double thermal;
  final double kinetic;
  final double explosive;
}

enum SnapshotBuiltinCharacter { all0, all5, alphaMax }

class SnapshotCharacterData {
  const SnapshotCharacterData.builtin(
    SnapshotBuiltinCharacter this.builtin, {
    this.names = const {},
  }) : characterId = null;

  const SnapshotCharacterData.custom({required String this.characterId, required this.names})
    : builtin = null;

  final SnapshotBuiltinCharacter? builtin;
  final String? characterId;
  final Map<String, String> names;
}

utils_pb.Icon _iconProto(SnapshotIcon icon) =>
    utils_pb.Icon(graphicId: icon.graphicId, iconId: icon.iconId);

SnapshotType _typeProto(SnapshotTypeData data, String context) {
  if (!data.names.containsKey("en")) {
    throw FitSnapshotBuildException(
      "$context (type ${data.typeId}) is missing the required 'en' name",
    );
  }
  final metaGroup = data.metaGroup;
  return SnapshotType(
    typeId: data.typeId,
    names: data.names.entries,
    icon: data.icon == null ? null : _iconProto(data.icon!),
    metaGroup: metaGroup == null
        ? null
        : SnapshotMetaGroup(
            metaGroupId: metaGroup.id,
            names: metaGroup.names.entries,
            icon: metaGroup.icon == null ? null : _iconProto(metaGroup.icon!),
          ),
  );
}

SnapshotDisplayValue _displayValueProto(SnapshotDisplayValueData data) => SnapshotDisplayValue(
  attributeId: data.attributeId,
  icon: data.icon == null ? null : _iconProto(data.icon!),
  text: data.text,
);

SnapshotModule _moduleProto(SnapshotModuleData data, String context) {
  final charge = data.charge;
  return SnapshotModule(
    type: _typeProto(data.type, context),
    state: data.state,
    charge: charge == null
        ? null
        : SnapshotCharge(
            type: _typeProto(charge.type, "$context charge"),
            quantity: charge.quantity,
          ),
    isTurret: data.isTurret ? true : null,
    isLauncher: data.isLauncher ? true : null,
    originType: data.originType == null ? null : _typeProto(data.originType!, "$context origin"),
    relatedValues: data.relatedValues.map(_displayValueProto),
  );
}

SnapshotTacticalMode _tacticalModeProto(SnapshotTacticalModeData data, String context) =>
    SnapshotTacticalMode(type: _typeProto(data.type, context), variant: data.variant);

SnapshotCharacter_Builtin _builtinProto(SnapshotBuiltinCharacter builtin) => switch (builtin) {
  SnapshotBuiltinCharacter.all0 => SnapshotCharacter_Builtin.ALL_0,
  SnapshotBuiltinCharacter.all5 => SnapshotCharacter_Builtin.ALL_5,
  SnapshotBuiltinCharacter.alphaMax => SnapshotCharacter_Builtin.ALPHA_MAX,
};

class FitSnapshotBuilder {
  FitSnapshotBuilder({
    required this.fitName,
    required this.ship,
    required this.layout,
    required this.character,
    required this.damageProfile,
    required this.lastModified,
    this.description,
    this.generator,
    this.checkoutId,
    this.serverId,
    List<SnapshotTacticalModeData> availableTacticalModes = const [],
    DateTime Function()? clock,
  }) : availableTacticalModes = List.of(availableTacticalModes),
       clock = clock ?? DateTime.now;

  final String fitName;
  final SnapshotTypeData ship;
  final SnapshotShipLayoutData layout;
  final SnapshotCharacterData character;
  final SnapshotDamageProfile damageProfile;
  final DateTime lastModified;
  final String? description;
  final String? generator;
  final String? checkoutId;
  final String? serverId;
  final List<SnapshotTacticalModeData> availableTacticalModes;
  final DateTime Function() clock;

  final Map<SnapshotRack, Map<int, SnapshotModuleData>> _racks = {
    for (final rack in SnapshotRack.values) rack: {},
  };
  final Map<int, (Subsystem_SubsystemType, SnapshotModuleData)> _subsystems = {};
  final Map<int, SnapshotModuleData> _implants = {};
  final List<SnapshotDroneData> _drones = [];
  final List<SnapshotFighterData> _fighters = [];
  final List<SnapshotBoosterData> _boosters = [];
  SnapshotTacticalModeData? _tacticalMode;
  SnapshotStatistics? _statistics;

  int _rackSize(SnapshotRack rack) => switch (rack) {
    SnapshotRack.high => layout.highSlots,
    SnapshotRack.medium => layout.mediumSlots,
    SnapshotRack.low => layout.lowSlots,
    SnapshotRack.rig => layout.rigSlots,
    SnapshotRack.service => layout.serviceSlots,
  };

  void setModule(SnapshotRack rack, int index, SnapshotModuleData module) {
    final size = _rackSize(rack);
    if (index < 0 || index >= size) {
      throw FitSnapshotBuildException("${rack.name} slot index $index out of range 0..${size - 1}");
    }
    final slots = _racks[rack]!;
    if (slots.containsKey(index)) {
      throw FitSnapshotBuildException("${rack.name} slot $index is already occupied");
    }
    slots[index] = module;
  }

  void setSubsystem(int index, Subsystem_SubsystemType subsystemType, SnapshotModuleData module) {
    if (index < 0 || index >= layout.subsystemSlots) {
      throw FitSnapshotBuildException(
        "subsystem slot index $index out of range 0..${layout.subsystemSlots - 1}",
      );
    }
    if (_subsystems.containsKey(index)) {
      throw FitSnapshotBuildException("subsystem slot $index is already occupied");
    }
    _subsystems[index] = (subsystemType, module);
  }

  void setImplant(int slotIndex, SnapshotModuleData module) {
    if (slotIndex < 1 || slotIndex > implantSlotCount) {
      throw FitSnapshotBuildException(
        "implant slot index $slotIndex out of range 1..$implantSlotCount",
      );
    }
    if (_implants.containsKey(slotIndex)) {
      throw FitSnapshotBuildException("implant slot $slotIndex is already occupied");
    }
    _implants[slotIndex] = module;
  }

  void addDrone(SnapshotDroneData drone) => _drones.add(drone);

  void addFighter(SnapshotFighterData fighter) => _fighters.add(fighter);

  void addBooster(SnapshotBoosterData booster) {
    if (_boosters.any((entry) => entry.slotIndex == booster.slotIndex)) {
      throw FitSnapshotBuildException("booster slot ${booster.slotIndex} is already occupied");
    }
    _boosters.add(booster);
  }

  void setTacticalMode(SnapshotTacticalModeData mode) => _tacticalMode = mode;

  void setStatistics(SnapshotStatistics statistics) => _statistics = statistics;

  List<SnapshotSlot> _buildRack(SnapshotRack rack) {
    final size = _rackSize(rack);
    final slots = _racks[rack]!;
    return [
      for (var index = 0; index < size; index++)
        SnapshotSlot(
          index: index,
          item: slots[index] == null
              ? null
              : _moduleProto(slots[index]!, "${rack.name} slot $index"),
        ),
    ];
  }

  FitSnapshot build() {
    final builtin = character.builtin;
    return FitSnapshot(
      version: currentFitSnapshotVersion,
      header: SnapshotHeader(
        fitName: fitName,
        description: description,
        lastModifiedMs: Int64(lastModified.millisecondsSinceEpoch),
        createdAtMs: Int64(clock().millisecondsSinceEpoch),
        generator: generator,
        checkoutId: checkoutId,
        serverId: serverId,
      ),
      ship: SnapshotShip(
        type: _typeProto(ship, "ship"),
        layout: SnapshotShipLayout(
          highSlots: layout.highSlots,
          mediumSlots: layout.mediumSlots,
          lowSlots: layout.lowSlots,
          rigSlots: layout.rigSlots,
          subsystemSlots: layout.subsystemSlots,
          serviceSlots: layout.serviceSlots,
          turretHardpoints: layout.turretHardpoints,
          launcherHardpoints: layout.launcherHardpoints,
          fighterTubes: layout.fighterTubes,
        ),
        availableTacticalModes: availableTacticalModes.map(
          (mode) => _tacticalModeProto(mode, "tactical mode"),
        ),
      ),
      highSlots: _buildRack(SnapshotRack.high),
      mediumSlots: _buildRack(SnapshotRack.medium),
      lowSlots: _buildRack(SnapshotRack.low),
      rigSlots: _buildRack(SnapshotRack.rig),
      subsystemSlots: [
        for (var index = 0; index < layout.subsystemSlots; index++)
          SnapshotSubsystemSlot(
            index: index,
            subsystemType: _subsystems[index]?.$1 ?? Subsystem_SubsystemType.UNKNOWN,
            item: _subsystems[index] == null
                ? null
                : _moduleProto(_subsystems[index]!.$2, "subsystem slot $index"),
          ),
      ],
      serviceSlots: _buildRack(SnapshotRack.service),
      tacticalMode: _tacticalMode == null
          ? null
          : _tacticalModeProto(_tacticalMode!, "tactical mode"),
      drones: _drones.map(
        (drone) => SnapshotDrone(
          type: _typeProto(drone.type, "drone"),
          state: drone.state,
          quantity: drone.quantity,
        ),
      ),
      fighters: _fighters.map(
        (fighter) => SnapshotFighter(
          type: _typeProto(fighter.type, "fighter"),
          state: fighter.state,
          quantity: fighter.quantity,
          maxSquadronSize: fighter.maxSquadronSize,
          group: fighter.group,
          abilities: fighter.abilities,
          relatedValues: fighter.relatedValues.map(_displayValueProto),
        ),
      ),
      implants: [
        for (var slotIndex = 1; slotIndex <= implantSlotCount; slotIndex++)
          SnapshotImplant(
            slotIndex: slotIndex,
            item: _implants[slotIndex] == null
                ? null
                : _moduleProto(_implants[slotIndex]!, "implant slot $slotIndex"),
          ),
      ],
      boosters: _boosters.map(
        (booster) => SnapshotBooster(
          slotIndex: booster.slotIndex,
          type: _typeProto(booster.type, "booster slot ${booster.slotIndex}"),
          state: booster.state,
        ),
      ),
      character: SnapshotCharacter(
        characterId: character.characterId,
        builtin: builtin == null ? SnapshotCharacter_Builtin.NONE : _builtinProto(builtin),
        names: character.names.entries,
      ),
      damageProfile: DamageProfile(
        em: damageProfile.em,
        thermal: damageProfile.thermal,
        kinetic: damageProfile.kinetic,
        explosive: damageProfile.explosive,
      ),
      statistics: _statistics,
    );
  }
}

List<int> encodeFitSnapshot(FitSnapshot snapshot) => snapshot.writeToBuffer();

FitSnapshot decodeFitSnapshot(List<int> data) {
  final snapshot = FitSnapshot.fromBuffer(data);
  if (snapshot.version != currentFitSnapshotVersion) {
    throw FitSnapshotBuildException(
      "unsupported snapshot version ${snapshot.version} (expected $currentFitSnapshotVersion)",
    );
  }
  return snapshot;
}
