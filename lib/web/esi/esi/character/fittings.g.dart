// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fittings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Fitting _$FittingFromJson(Map<String, dynamic> json) => _Fitting(
      fittingID: (json['fitting_id'] as num).toInt(),
      shipTypeID: (json['ship_type_id'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => FittingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FittingToJson(_Fitting instance) => <String, dynamic>{
      'fitting_id': instance.fittingID,
      'ship_type_id': instance.shipTypeID,
      'name': instance.name,
      'description': instance.description,
      'items': instance.items,
    };

_FittingItem _$FittingItemFromJson(Map<String, dynamic> json) => _FittingItem(
      typeID: (json['type_id'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      flag: FittingItemFlag.fromJson(json['flag'] as String),
    );

Map<String, dynamic> _$FittingItemToJson(_FittingItem instance) =>
    <String, dynamic>{
      'type_id': instance.typeID,
      'quantity': instance.quantity,
      'flag': FittingItemFlag.toJson(instance.flag),
    };
