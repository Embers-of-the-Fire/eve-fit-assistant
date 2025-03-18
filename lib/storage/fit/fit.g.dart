// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fit.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FitRecord _$FitRecordFromJson(Map<String, dynamic> json) => FitRecord(
      brief: FitRecordBrief.fromJson(json['brief'] as Map<String, dynamic>),
      body: Fit.fromJson(json['body'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$FitRecordToJson(FitRecord instance) => <String, dynamic>{
      'brief': instance.brief.toJson(),
      'body': instance.body.toJson(),
    };

Fit _$FitFromJson(Map<String, dynamic> json) => Fit(
      shipID: (json['shipID'] as num).toInt(),
      characterID: json['characterID'] as String? ?? predefinedLevelAll5,
      damageProfile: json['damageProfile'] == null
          ? DamageProfile.defaultProfile
          : DamageProfile.fromJson(
              json['damageProfile'] as Map<String, dynamic>),
      high: (json['high'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      med: (json['med'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      low: (json['low'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      rig: (json['rig'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subsystem: (json['subsystem'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      drone: (json['drone'] as List<dynamic>?)
              ?.map((e) => DroneItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      fighter: (json['fighter'] as List<dynamic>?)
              ?.map((e) => FighterItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      implant: (json['implant'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      booster: (json['booster'] as List<dynamic>?)
              ?.map((e) => SlotItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tacticalModeID: (json['tacticalModeID'] as num?)?.toInt(),
      dynamicItems: (json['dynamicItems'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
                int.parse(k), DynamicItem.fromJson(e as Map<String, dynamic>)),
          ) ??
          {},
    );

Map<String, dynamic> _$FitToJson(Fit instance) => <String, dynamic>{
      'shipID': instance.shipID,
      'characterID': instance.characterID,
      'damageProfile': instance.damageProfile.toJson(),
      'high': instance.high.map((e) => e?.toJson()).toList(),
      'med': instance.med.map((e) => e?.toJson()).toList(),
      'low': instance.low.map((e) => e?.toJson()).toList(),
      'rig': instance.rig.map((e) => e?.toJson()).toList(),
      'subsystem': instance.subsystem.map((e) => e?.toJson()).toList(),
      'drone': instance.drone.map((e) => e.toJson()).toList(),
      'fighter': instance.fighter.map((e) => e.toJson()).toList(),
      'implant': instance.implant.map((e) => e?.toJson()).toList(),
      'booster': instance.booster.map((e) => e.toJson()).toList(),
      'dynamicItems': instance.dynamicItems
          .map((k, e) => MapEntry(k.toString(), e.toJson())),
      'tacticalModeID': instance.tacticalModeID,
    };

_SlotItem _$SlotItemFromJson(Map<String, dynamic> json) => _SlotItem(
      itemID: (json['itemID'] as num).toInt(),
      isDynamic: json['isDynamic'] as bool? ?? false,
      chargeID: (json['chargeID'] as num?)?.toInt(),
      state: $enumDecode(_$SlotStateEnumMap, json['state']),
    );

Map<String, dynamic> _$SlotItemToJson(_SlotItem instance) => <String, dynamic>{
      'itemID': instance.itemID,
      'isDynamic': instance.isDynamic,
      'chargeID': instance.chargeID,
      'state': _$SlotStateEnumMap[instance.state]!,
    };

const _$SlotStateEnumMap = {
  SlotState.passive: 0,
  SlotState.online: 1,
  SlotState.active: 2,
  SlotState.overload: 3,
};

_DroneItem _$DroneItemFromJson(Map<String, dynamic> json) => _DroneItem(
      itemID: (json['itemID'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      state: $enumDecode(_$DroneStateEnumMap, json['state']),
    );

Map<String, dynamic> _$DroneItemToJson(_DroneItem instance) =>
    <String, dynamic>{
      'itemID': instance.itemID,
      'amount': instance.amount,
      'state': _$DroneStateEnumMap[instance.state]!,
    };

const _$DroneStateEnumMap = {
  DroneState.passive: 0,
  DroneState.active: 1,
};

_FighterItem _$FighterItemFromJson(Map<String, dynamic> json) => _FighterItem(
      itemID: (json['itemID'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      ability: (json['ability'] as num).toInt(),
      state: $enumDecode(_$DroneStateEnumMap, json['state']),
    );

Map<String, dynamic> _$FighterItemToJson(_FighterItem instance) =>
    <String, dynamic>{
      'itemID': instance.itemID,
      'amount': instance.amount,
      'ability': instance.ability,
      'state': _$DroneStateEnumMap[instance.state]!,
    };

_DynamicItem _$DynamicItemFromJson(Map<String, dynamic> json) => _DynamicItem(
      mutaplasmidID: (json['mutaplasmidID'] as num).toInt(),
      baseType: (json['baseType'] as num).toInt(),
      outType: (json['outType'] as num).toInt(),
      dynamicAttributes:
          (json['dynamicAttributes'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(int.parse(k), (e as num).toDouble()),
      ),
    );

Map<String, dynamic> _$DynamicItemToJson(_DynamicItem instance) =>
    <String, dynamic>{
      'mutaplasmidID': instance.mutaplasmidID,
      'baseType': instance.baseType,
      'outType': instance.outType,
      'dynamicAttributes':
          instance.dynamicAttributes.map((k, e) => MapEntry(k.toString(), e)),
    };
