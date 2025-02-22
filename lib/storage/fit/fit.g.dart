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
      drone: (json['drone'] as List<dynamic>)
          .map((e) => DroneItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      implant: (json['implant'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      tacticalModeID: (json['tacticalModeID'] as num?)?.toInt(),
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
      'implant': instance.implant.map((e) => e?.toJson()).toList(),
      'tacticalModeID': instance.tacticalModeID,
    };

_$SlotItemImpl _$$SlotItemImplFromJson(Map<String, dynamic> json) =>
    _$SlotItemImpl(
      itemID: (json['itemID'] as num).toInt(),
      chargeID: (json['chargeID'] as num?)?.toInt(),
      state: $enumDecode(_$SlotStateEnumMap, json['state']),
    );

Map<String, dynamic> _$$SlotItemImplToJson(_$SlotItemImpl instance) =>
    <String, dynamic>{
      'itemID': instance.itemID,
      'chargeID': instance.chargeID,
      'state': _$SlotStateEnumMap[instance.state]!,
    };

const _$SlotStateEnumMap = {
  SlotState.passive: 0,
  SlotState.online: 1,
  SlotState.active: 2,
  SlotState.overload: 3,
};

_$DroneItemImpl _$$DroneItemImplFromJson(Map<String, dynamic> json) =>
    _$DroneItemImpl(
      itemID: (json['itemID'] as num).toInt(),
      amount: (json['amount'] as num).toInt(),
      state: $enumDecode(_$DroneStateEnumMap, json['state']),
    );

Map<String, dynamic> _$$DroneItemImplToJson(_$DroneItemImpl instance) =>
    <String, dynamic>{
      'itemID': instance.itemID,
      'amount': instance.amount,
      'state': _$DroneStateEnumMap[instance.state]!,
    };

const _$DroneStateEnumMap = {
  DroneState.passive: 0,
  DroneState.active: 1,
};
