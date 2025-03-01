// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'damage_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DamageProfile _$DamageProfileFromJson(Map<String, dynamic> json) =>
    _DamageProfile(
      em: (json['em'] as num).toDouble(),
      thermal: (json['thermal'] as num).toDouble(),
      kinetic: (json['kinetic'] as num).toDouble(),
      explosive: (json['explosive'] as num).toDouble(),
    );

Map<String, dynamic> _$DamageProfileToJson(_DamageProfile instance) =>
    <String, dynamic>{
      'em': instance.em,
      'thermal': instance.thermal,
      'kinetic': instance.kinetic,
      'explosive': instance.explosive,
    };
