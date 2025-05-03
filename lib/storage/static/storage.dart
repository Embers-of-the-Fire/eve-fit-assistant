import 'dart:developer' as dev;
import 'dart:io';

import 'package:eve_fit_assistant/native/codegen/constant/bundle.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/static/attribute.dart';
import 'package:eve_fit_assistant/storage/static/bundle.dart';
import 'package:eve_fit_assistant/storage/static/damage_profile.dart';
import 'package:eve_fit_assistant/storage/static/dynamic_item.dart';
import 'package:eve_fit_assistant/storage/static/fighter.dart';
import 'package:eve_fit_assistant/storage/static/groups.dart';
import 'package:eve_fit_assistant/storage/static/icon.dart';
import 'package:eve_fit_assistant/storage/static/implant_group.dart';
import 'package:eve_fit_assistant/storage/static/market.dart';
import 'package:eve_fit_assistant/storage/static/ship_subsystems.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/static/skills.dart';
import 'package:eve_fit_assistant/storage/static/slot_group.dart';
import 'package:eve_fit_assistant/storage/static/tactical_mode.dart';
import 'package:eve_fit_assistant/storage/static/type_skills.dart';
import 'package:eve_fit_assistant/storage/static/types.dart';
import 'package:eve_fit_assistant/storage/static/units.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/loading.dart';

const String _staticStorageLoadingKey = 'static';

class StaticStorage {
  late final ReadonlyMap<int, TypeItem> _types;
  late final ReadonlyMap<int, MarketGroup> _marketGroups;
  late final ReadonlyMap<int, Group> _groups;
  late final ReadonlyMap<int, Ship> _ships;
  late final ReadonlyMap<int, TacticalModeShip> _tacticalModes;
  late final ReadonlyMap<int, UnitItem> _units;
  late final ReadonlyMap<int, AttributeItem> _attributes;
  late final ReadonlyMap<int, SkillItem> _skills;
  late final ReadonlyMap<int, TypeSkill> _typeSkills;
  late final ReadonlyMap<int, Fighter> _fighters;
  late final ReadonlyMap<String, DamageProfileGroup> _damageProfiles;
  late final ReadonlyMap<int, DynamicItem> _dynamicItems;
  late final ReadonlyMap<int, List<int>> _dynamicTypes;
  late final List<ImplantGroup> _implantGroups;
  late final StaticIcon _icons;
  late final TypeSlotStorage _typeSlot;
  late final ShipSubsystemStorage _subsystems;
  late StaticVersionInfo? _version;

  ReadonlyMap<int, TypeItem> get types => _types;

  ReadonlyMap<int, MarketGroup> get marketGroups => _marketGroups;

  ReadonlyMap<int, Group> get groups => _groups;

  ReadonlyMap<int, Ship> get ships => _ships;

  ReadonlyMap<int, TacticalModeShip> get tacticalModes => _tacticalModes;

  ReadonlyMap<int, UnitItem> get units => _units;

  ReadonlyMap<int, AttributeItem> get attributes => _attributes;

  ReadonlyMap<int, SkillItem> get skills => _skills;

  ReadonlyMap<int, TypeSkill> get typeSkills => _typeSkills;

  ReadonlyMap<int, Fighter> get fighters => _fighters;

  ReadonlyMap<String, DamageProfileGroup> get damageProfiles => _damageProfiles;

  ReadonlyMap<int, DynamicItem> get dynamicItems => _dynamicItems;

  ReadonlyMap<int, List<int>> get dynamicTypes => _dynamicTypes;

  List<ImplantGroup> get implantGroups => _implantGroups;

  MarketGroup get shipMarketGroup => _marketGroups[4]!;

  StaticIcon get icons => _icons;

  TypeSlotStorage get typeSlot => _typeSlot;

  ShipSubsystemStorage get subsystems => _subsystems;

  StaticVersionInfo? get version => _version;

  StaticStorage();

  Future<void> init() async {
    final start = DateTime.now();
    dev.log(
      'StaticStorage.init',
      name: 'storage',
      time: start,
    );
    GlobalLoading().add(_staticStorageLoadingKey, '加载静态资产');

    final staticStorageDir = await getStaticStorageDir();
    final staticVersion = await StaticVersionInfo.read();
    if (staticVersion == null) {
      await unpackBundledStorage();
    } else if (bundledStaticVersion > staticVersion) {
      await staticStorageDir.delete(recursive: true);
      await unpackBundledStorage();
    }

    _types = await TypeItem.read(staticStorageDir);
    _marketGroups = await MarketGroup.read(staticStorageDir);
    _groups = await Group.read(staticStorageDir);
    _ships = await Ship.read(staticStorageDir);
    _tacticalModes = await TacticalModeShip.read(staticStorageDir);
    _implantGroups = await ImplantGroup.read(staticStorageDir);
    _units = await UnitItem.read(staticStorageDir);
    _attributes = await AttributeItem.read(staticStorageDir);
    _skills = await SkillItem.read(staticStorageDir);
    _typeSkills = await TypeSkill.read(staticStorageDir);
    _fighters = await Fighter.read(staticStorageDir);
    _damageProfiles = await DamageProfileGroup.read(staticStorageDir);
    _dynamicItems = await DynamicItem.read(staticStorageDir);
    _dynamicTypes = await readDynamicType(staticStorageDir);
    _icons = await StaticIcon.init();
    _typeSlot = await TypeSlotStorage.read(staticStorageDir);
    _subsystems = await ShipSubsystemStorage.read(staticStorageDir);
    _version = await StaticVersionInfo.read();

    GlobalLoading().dismiss(_staticStorageLoadingKey);
    final end = DateTime.now();
    dev.log(
      'StaticStorage.init done in ${end.difference(start).inSeconds}s',
      name: 'storage',
      time: end,
    );
  }
}

Future<Directory> getStaticStorageDir({bool create = false}) async {
  final Directory storageDir = await getStorageDir(create: create);
  final Directory staticStorageDir = Directory('${storageDir.path}/static');
  if (create) {
    if (!await staticStorageDir.exists()) {
      await staticStorageDir.create(recursive: true);
    }
  }
  return staticStorageDir;
}

class StaticVersionInfo {
  final int createTime;

  const StaticVersionInfo({required this.createTime});

  factory StaticVersionInfo.fromText(String text) =>
      StaticVersionInfo(createTime: int.parse(text.replaceAll('\n', '')));

  String toText() => createTime.toString();

  bool operator >(StaticVersionInfo local) => createTime > local.createTime;

  static Future<StaticVersionInfo?> read() async {
    final File? versionFile = await _getStaticVersionFile();
    if (versionFile == null) {
      return null;
    }
    final String content = await versionFile.readAsString();
    return StaticVersionInfo.fromText(content);
  }

  String display() {
    final DateTime time = fromSecondsSinceEpoch(createTime);
    return time.toIso8601String();
  }
}

Future<File?> _getStaticVersionFile() async {
  final Directory staticStorageDir = await getStaticStorageDir();
  final File versionFile = File('${staticStorageDir.path}/version');
  if (!await versionFile.exists()) {
    return null;
  }
  return versionFile;
}
