// ignore_for_file: invalid_annotation_target

import 'dart:convert';
import 'dart:developer';

import 'package:animated_tree_view/helpers/collection_utils.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'fittings.freezed.dart';
part 'fittings.g.dart';

@freezed
abstract class Fitting with _$Fitting {
  @JsonSerializable()
  const factory Fitting({
    @JsonKey(name: 'fitting_id') required int fittingID,
    @JsonKey(name: 'ship_type_id') required int shipTypeID,
    required String name,
    required String description,
    required List<FittingItem> items,
  }) = _Fitting;

  factory Fitting.fromJson(Map<String, dynamic> json) => _$FittingFromJson(json);

  const Fitting._();

  Fit toFit() {
    final fit = Fit.init(shipTypeID);
    for (final item in items) {
      if (item.flag.isDrone) {
        fit.drone
            .add(DroneItem(itemID: item.typeID, amount: item.quantity, state: DroneState.passive));
      } else if (item.flag.isFighter) {
        fit.fighter.add(FighterItem(
            itemID: item.typeID, amount: item.quantity, ability: 0, state: DroneState.passive));
      } else {
        final slotInfo = item.flag.slotInfo;
        if (slotInfo == null) continue;
        fit.getSlots(slotInfo.$1)[slotInfo.$2] =
            SlotItem(itemID: item.typeID, chargeID: null, state: SlotState.online);
      }
    }
    return fit;
  }
}

@freezed
abstract class FittingPost with _$FittingPost {
  @JsonSerializable()
  const factory FittingPost({
    @JsonKey(name: 'ship_type_id') required int shipTypeID,
    required String name,
    required String description,
    required List<FittingItem> items,
  }) = _FittingPost;

  factory FittingPost.fromJson(Map<String, dynamic> json) => _$FittingPostFromJson(json);

  const FittingPost._();

  factory FittingPost.fromFit(FitRecord record) {
    final items = <FittingItem>[];
    final fit = record.body;
    for (final (type, slot) in [
      (FitItemType.high, fit.high),
      (FitItemType.med, fit.med),
      (FitItemType.low, fit.low),
      (FitItemType.rig, fit.rig),
      (FitItemType.subsystem, fit.subsystem)
    ]) {
      for (final (index, item) in slot.filterNotNull().enumerate()) {
        items.add(FittingItem(
          typeID: item.isDynamic ? fit.dynamicItems[item.itemID]!.outType : item.itemID,
          quantity: 1,
          flag: FittingItemFlag.fromSlotInfo(type, index),
        ));
        if (item.chargeID != null) {
          items.add(FittingItem(
            typeID: item.chargeID!,
            quantity: 1,
            flag: FittingItemFlag.cargo,
          ));
        }
      }
    }
    for (final drone in fit.drone) {
      items.add(FittingItem(
        typeID: drone.itemID,
        quantity: drone.amount,
        flag: FittingItemFlag.droneBay,
      ));
    }
    for (final fighter in fit.fighter) {
      items.add(FittingItem(
        typeID: fighter.itemID,
        quantity: fighter.amount,
        flag: FittingItemFlag.fighterBay,
      ));
    }
    for (final implant in fit.implant) {
      if (implant == null) continue;
      items.add(FittingItem(
        typeID: implant.itemID,
        quantity: 1,
        flag: FittingItemFlag.cargo,
      ));
    }
    for (final booster in fit.booster) {
      items.add(FittingItem(
        typeID: booster.itemID,
        quantity: 1,
        flag: FittingItemFlag.cargo,
      ));
    }
    return FittingPost(
      shipTypeID: fit.shipID,
      name: record.brief.name,
      description: record.brief.description,
      items: items,
    );
  }
}

@freezed
abstract class FittingItem with _$FittingItem {
  @JsonSerializable()
  const factory FittingItem({
    @JsonKey(name: 'type_id') required int typeID,
    required int quantity,
    @JsonKey(fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
    required FittingItemFlag flag,
  }) = _FittingItem;

  factory FittingItem.fromJson(Map<String, dynamic> json) => _$FittingItemFromJson(json);
}

enum FittingItemFlag {
  cargo,
  droneBay,
  fighterBay,
  hiSlot0,
  hiSlot1,
  hiSlot2,
  hiSlot3,
  hiSlot4,
  hiSlot5,
  hiSlot6,
  hiSlot7,
  invalid,
  loSlot0,
  loSlot1,
  loSlot2,
  loSlot3,
  loSlot4,
  loSlot5,
  loSlot6,
  loSlot7,
  medSlot0,
  medSlot1,
  medSlot2,
  medSlot3,
  medSlot4,
  medSlot5,
  medSlot6,
  medSlot7,
  rigSlot0,
  rigSlot1,
  rigSlot2,
  serviceSlot0,
  serviceSlot1,
  serviceSlot2,
  serviceSlot3,
  serviceSlot4,
  serviceSlot5,
  serviceSlot6,
  serviceSlot7,
  subSystemSlot0,
  subSystemSlot1,
  subSystemSlot2,
  subSystemSlot3;

  static String toJson(FittingItemFlag flag) => switch (flag) {
        cargo => 'Cargo',
        droneBay => 'DroneBay',
        fighterBay => 'FighterBay',
        hiSlot0 => 'HiSlot0',
        hiSlot1 => 'HiSlot1',
        hiSlot2 => 'HiSlot2',
        hiSlot3 => 'HiSlot3',
        hiSlot4 => 'HiSlot4',
        hiSlot5 => 'HiSlot5',
        hiSlot6 => 'HiSlot6',
        hiSlot7 => 'HiSlot7',
        invalid => 'Invalid',
        loSlot0 => 'LoSlot0',
        loSlot1 => 'LoSlot1',
        loSlot2 => 'LoSlot2',
        loSlot3 => 'LoSlot3',
        loSlot4 => 'LoSlot4',
        loSlot5 => 'LoSlot5',
        loSlot6 => 'LoSlot6',
        loSlot7 => 'LoSlot7',
        medSlot0 => 'MedSlot0',
        medSlot1 => 'MedSlot1',
        medSlot2 => 'MedSlot2',
        medSlot3 => 'MedSlot3',
        medSlot4 => 'MedSlot4',
        medSlot5 => 'MedSlot5',
        medSlot6 => 'MedSlot6',
        medSlot7 => 'MedSlot7',
        rigSlot0 => 'RigSlot0',
        rigSlot1 => 'RigSlot1',
        rigSlot2 => 'RigSlot2',
        serviceSlot0 => 'ServiceSlot0',
        serviceSlot1 => 'ServiceSlot1',
        serviceSlot2 => 'ServiceSlot2',
        serviceSlot3 => 'ServiceSlot3',
        serviceSlot4 => 'ServiceSlot4',
        serviceSlot5 => 'ServiceSlot5',
        serviceSlot6 => 'ServiceSlot6',
        serviceSlot7 => 'ServiceSlot7',
        subSystemSlot0 => 'SubSystemSlot0',
        subSystemSlot1 => 'SubSystemSlot1',
        subSystemSlot2 => 'SubSystemSlot2',
        subSystemSlot3 => 'SubSystemSlot3',
      };

  factory FittingItemFlag.fromJson(String json) => switch (json) {
        'Cargo' => cargo,
        'DroneBay' => droneBay,
        'FighterBay' => fighterBay,
        'HiSlot0' => hiSlot0,
        'HiSlot1' => hiSlot1,
        'HiSlot2' => hiSlot2,
        'HiSlot3' => hiSlot3,
        'HiSlot4' => hiSlot4,
        'HiSlot5' => hiSlot5,
        'HiSlot6' => hiSlot6,
        'HiSlot7' => hiSlot7,
        'Invalid' => invalid,
        'LoSlot0' => loSlot0,
        'LoSlot1' => loSlot1,
        'LoSlot2' => loSlot2,
        'LoSlot3' => loSlot3,
        'LoSlot4' => loSlot4,
        'LoSlot5' => loSlot5,
        'LoSlot6' => loSlot6,
        'LoSlot7' => loSlot7,
        'MedSlot0' => medSlot0,
        'MedSlot1' => medSlot1,
        'MedSlot2' => medSlot2,
        'MedSlot3' => medSlot3,
        'MedSlot4' => medSlot4,
        'MedSlot5' => medSlot5,
        'MedSlot6' => medSlot6,
        'MedSlot7' => medSlot7,
        'RigSlot0' => rigSlot0,
        'RigSlot1' => rigSlot1,
        'RigSlot2' => rigSlot2,
        'ServiceSlot0' => serviceSlot0,
        'ServiceSlot1' => serviceSlot1,
        'ServiceSlot2' => serviceSlot2,
        'ServiceSlot3' => serviceSlot3,
        'ServiceSlot4' => serviceSlot4,
        'ServiceSlot5' => serviceSlot5,
        'ServiceSlot6' => serviceSlot6,
        'ServiceSlot7' => serviceSlot7,
        'SubSystemSlot0' => subSystemSlot0,
        'SubSystemSlot1' => subSystemSlot1,
        'SubSystemSlot2' => subSystemSlot2,
        'SubSystemSlot3' => subSystemSlot3,
        _ => throw Exception('Invalid FittingItemFlag: $json'),
      };

  bool get isDrone => switch (this) {
        droneBay => true,
        _ => false,
      };

  bool get isFighter => switch (this) {
        fighterBay => true,
        _ => false,
      };

  (FitItemType, int)? get slotInfo => switch (this) {
        serviceSlot0 ||
        serviceSlot1 ||
        serviceSlot2 ||
        serviceSlot3 ||
        serviceSlot4 ||
        serviceSlot5 ||
        serviceSlot6 ||
        serviceSlot7 ||
        cargo ||
        droneBay ||
        fighterBay =>
          null,
        hiSlot0 => (FitItemType.high, 0),
        hiSlot1 => (FitItemType.high, 1),
        hiSlot2 => (FitItemType.high, 2),
        hiSlot3 => (FitItemType.high, 3),
        hiSlot4 => (FitItemType.high, 4),
        hiSlot5 => (FitItemType.high, 5),
        hiSlot6 => (FitItemType.high, 6),
        hiSlot7 => (FitItemType.high, 7),
        invalid => null,
        loSlot0 => (FitItemType.low, 0),
        loSlot1 => (FitItemType.low, 1),
        loSlot2 => (FitItemType.low, 2),
        loSlot3 => (FitItemType.low, 3),
        loSlot4 => (FitItemType.low, 4),
        loSlot5 => (FitItemType.low, 5),
        loSlot6 => (FitItemType.low, 6),
        loSlot7 => (FitItemType.low, 7),
        medSlot0 => (FitItemType.med, 0),
        medSlot1 => (FitItemType.med, 1),
        medSlot2 => (FitItemType.med, 2),
        medSlot3 => (FitItemType.med, 3),
        medSlot4 => (FitItemType.med, 4),
        medSlot5 => (FitItemType.med, 5),
        medSlot6 => (FitItemType.med, 6),
        medSlot7 => (FitItemType.med, 7),
        rigSlot0 => (FitItemType.rig, 0),
        rigSlot1 => (FitItemType.rig, 1),
        rigSlot2 => (FitItemType.rig, 2),
        subSystemSlot0 => (FitItemType.subsystem, 0),
        subSystemSlot1 => (FitItemType.subsystem, 1),
        subSystemSlot2 => (FitItemType.subsystem, 2),
        subSystemSlot3 => (FitItemType.subsystem, 3),
      };

  factory FittingItemFlag.fromSlotInfo(FitItemType type, int index) => switch ((type, index)) {
        (FitItemType.high, 0) => hiSlot0,
        (FitItemType.high, 1) => hiSlot1,
        (FitItemType.high, 2) => hiSlot2,
        (FitItemType.high, 3) => hiSlot3,
        (FitItemType.high, 4) => hiSlot4,
        (FitItemType.high, 5) => hiSlot5,
        (FitItemType.high, 6) => hiSlot6,
        (FitItemType.high, 7) => hiSlot7,
        (FitItemType.med, 0) => medSlot0,
        (FitItemType.med, 1) => medSlot1,
        (FitItemType.med, 2) => medSlot2,
        (FitItemType.med, 3) => medSlot3,
        (FitItemType.med, 4) => medSlot4,
        (FitItemType.med, 5) => medSlot5,
        (FitItemType.med, 6) => medSlot6,
        (FitItemType.med, 7) => medSlot7,
        (FitItemType.low, 0) => loSlot0,
        (FitItemType.low, 1) => loSlot1,
        (FitItemType.low, 2) => loSlot2,
        (FitItemType.low, 3) => loSlot3,
        (FitItemType.low, 4) => loSlot4,
        (FitItemType.low, 5) => loSlot5,
        (FitItemType.low, 6) => loSlot6,
        (FitItemType.low, 7) => loSlot7,
        (FitItemType.rig, 0) => rigSlot0,
        (FitItemType.rig, 1) => rigSlot1,
        (FitItemType.rig, 2) => rigSlot2,
        (FitItemType.subsystem, 0) => subSystemSlot0,
        (FitItemType.subsystem, 1) => subSystemSlot1,
        (FitItemType.subsystem, 2) => subSystemSlot2,
        (FitItemType.subsystem, 3) => subSystemSlot3,
        (FitItemType.drone, _) => droneBay,
        (FitItemType.fighter, _) => fighterBay,
        _ => cargo,
      };
}

Future<List<Fitting>> characterFittings() async {
  final characterID = (await EsiDataStorage.instance.getCharacter())!.characterID;
  final url =
      Uri.parse('${esiUrl(Preference().esiAuthServer)}/latest/characters/$characterID/fittings')
          .replace(
    queryParameters: {
      'token': (await EsiAuth().getTokensAuthorized())!.accessToken,
      'datasource': Preference().esiAuthServer.datasourceText,
    },
  );
  final response = await http.get(url);
  final list = (jsonDecode(response.body) as List)
      .map((e) => Fitting.fromJson(e as Map<String, dynamic>))
      .toList();
  final sort = Preference().esiFitListSort;
  switch (sort) {
    case EsiFitListSort.internalID:
      list.sort((a, b) => a.fittingID.compareTo(b.fittingID));
      break;
    case EsiFitListSort.ship:
      list.sort((a, b) => a.shipTypeID.compareTo(b.shipTypeID));
      break;
    case EsiFitListSort.preserve:
      break;
  }
  return list;
}

extension ImportEsiFit on FitStorage {
  Future<FitRecord> importEsiFit(Fitting fit) async {
    final newRecord = await createFit(fit.name, fit.shipTypeID);
    final newBrief = newRecord.brief;
    final copiedRecord = FitRecord(
        brief: FitRecordBrief(
            id: newBrief.id,
            name: fit.name,
            description: fit.description,
            shipID: fit.shipTypeID,
            createTime: newBrief.createTime,
            lastModifyTime: newBrief.lastModifyTime),
        body: fit.toFit());
    await copiedRecord.save();
    await save();
    return copiedRecord;
  }
}

Future<int> exportToCharacterFittings(FitRecord fit) async {
  final data = FittingPost.fromFit(fit);
  final characterID = (await EsiDataStorage.instance.getCharacter())!.characterID;
  final url =
      Uri.parse('${esiUrl(Preference().esiAuthServer)}/latest/characters/$characterID/fittings/')
          .replace(
    queryParameters: {
      'token': (await EsiAuth().getTokensAuthorized())!.accessToken,
      'datasource': Preference().esiAuthServer.datasourceText,
    },
  );
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(data.toJson()),
  );
  log(response.body, name: 'exportToCharacterFittings');
  return jsonDecode(response.body)['fitting_id'] as int;
}

Future<void> deleteCharacterFitting(int fittingID) async {
  final characterID = (await EsiDataStorage.instance.getCharacter())!.characterID;
  final url = Uri.parse(
          '${esiUrl(Preference().esiAuthServer)}/latest/characters/$characterID/fittings/$fittingID/')
      .replace(
    queryParameters: {
      'token': (await EsiAuth().getTokensAuthorized())!.accessToken,
      'datasource': Preference().esiAuthServer.datasourceText,
    },
  );
  await http.delete(url);
}
