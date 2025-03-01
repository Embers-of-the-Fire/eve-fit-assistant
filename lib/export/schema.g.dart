// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FitExport _$FitExportFromJson(Map<String, dynamic> json) => _FitExport(
      name: json['name'] as String,
      description: json['description'] as String,
      shipID: (json['shipID'] as num).toInt(),
      damageProfile:
          DamageProfile.fromJson(json['damageProfile'] as Map<String, dynamic>),
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
      subSystem: (json['subSystem'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      drone: (json['drone'] as List<dynamic>)
          .map((e) => DroneItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      fighter: (json['fighter'] as List<dynamic>)
          .map((e) => FighterItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      implant: (json['implant'] as List<dynamic>)
          .map((e) =>
              e == null ? null : SlotItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      dynamicItems: (json['dynamicItems'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            int.parse(k), DynamicItem.fromJson(e as Map<String, dynamic>)),
      ),
      tacticalModeID: (json['tacticalModeID'] as num?)?.toInt(),
    );

Map<String, dynamic> _$FitExportToJson(_FitExport instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'shipID': instance.shipID,
      'damageProfile': instance.damageProfile,
      'high': instance.high,
      'med': instance.med,
      'low': instance.low,
      'rig': instance.rig,
      'subSystem': instance.subSystem,
      'drone': instance.drone,
      'fighter': instance.fighter,
      'implant': instance.implant,
      'dynamicItems':
          instance.dynamicItems.map((k, e) => MapEntry(k.toString(), e)),
      'tacticalModeID': instance.tacticalModeID,
    };
