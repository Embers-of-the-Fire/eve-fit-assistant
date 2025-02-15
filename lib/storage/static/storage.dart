import 'dart:developer' as dev;
import 'dart:io';

import 'package:eve_fit_assistant/native/codegen/constant/bundle.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/static/bundle.dart';
import 'package:eve_fit_assistant/storage/static/groups.dart';
import 'package:eve_fit_assistant/storage/static/icon.dart';
import 'package:eve_fit_assistant/storage/static/market.dart';
import 'package:eve_fit_assistant/storage/static/ships.dart';
import 'package:eve_fit_assistant/storage/static/slot_group.dart';
import 'package:eve_fit_assistant/storage/static/types.dart';
import 'package:eve_fit_assistant/utils/map.dart';

class StaticStorage {
  late ReadonlyMap<int, TypeAbbr> _typesAbbr;
  late ReadonlyMap<int, MarketGroup> _marketGroups;
  late ReadonlyMap<int, Group> _groups;
  late ReadonlyMap<int, Ship> _ships;
  late StaticIcon _icons;
  late TypeSlotStorage _typeSlot;
  late StaticVersionInfo? _version;

  ReadonlyMap<int, TypeAbbr> get typesAbbr => _typesAbbr;

  ReadonlyMap<int, MarketGroup> get marketGroups => _marketGroups;

  ReadonlyMap<int, Group> get groups => _groups;

  ReadonlyMap<int, Ship> get ships => _ships;

  MarketGroup get shipMarketGroup => _marketGroups[4]!;

  StaticIcon get icons => _icons;

  TypeSlotStorage get typeSlot => _typeSlot;

  StaticVersionInfo? get version => _version;

  StaticStorage();

  Future<void> init({bool autoDismiss = true}) async {
    final start = DateTime.now();
    dev.log(
      'StaticStorage.init',
      name: 'storage',
      time: start,
    );

    final staticStorageDir = await getStaticStorageDir();
    final staticVersion = await StaticVersionInfo.read();
    if (staticVersion == null) {
      await unpackBundledStorage(showLoading: false, autoDismiss: autoDismiss);
    } else if (dataVersion > staticVersion) {
      await staticStorageDir.delete(recursive: true);
      await unpackBundledStorage(showLoading: false, autoDismiss: autoDismiss);
    }

    _typesAbbr = await TypeAbbr.read(staticStorageDir);
    _marketGroups = await MarketGroup.read(staticStorageDir);
    _groups = await Group.read(staticStorageDir);
    _ships = await Ship.read(staticStorageDir);
    _icons = await StaticIcon.init();
    _typeSlot = await TypeSlotStorage.read(staticStorageDir);
    _version = await StaticVersionInfo.read();

    final end = DateTime.now();
    dev.log(
      'StaticStorage.init done in ${start.difference(end).inSeconds}s',
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

  factory StaticVersionInfo.fromText(String text) {
    return StaticVersionInfo(createTime: int.parse(text));
  }

  String toText() {
    return createTime.toString();
  }

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
    final DateTime time = DateTime.fromMillisecondsSinceEpoch(createTime * 1000);
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
