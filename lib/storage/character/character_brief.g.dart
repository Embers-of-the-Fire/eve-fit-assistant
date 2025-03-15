// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character_brief.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharacterBrief _$CharacterBriefFromJson(Map<String, dynamic> json) =>
    CharacterBrief(
      id: json['id'] as String,
      lastModifyTime: (json['lastModifyTime'] as num).toInt(),
      name: json['name'] as String,
      description: json['description'] as String,
    );

Map<String, dynamic> _$CharacterBriefToJson(CharacterBrief instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lastModifyTime': instance.lastModifyTime,
      'name': instance.name,
      'description': instance.description,
    };
