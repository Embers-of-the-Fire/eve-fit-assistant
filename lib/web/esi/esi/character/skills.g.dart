// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skills.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CharacterSkills _$CharacterSkillsFromJson(Map<String, dynamic> json) =>
    _CharacterSkills(
      totalSP: (json['total_sp'] as num).toInt(),
      unallocatedSP: (json['unallocated_sp'] as num).toInt(),
      skills: (json['skills'] as List<dynamic>)
          .map((e) => CharacterSkillItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CharacterSkillsToJson(_CharacterSkills instance) =>
    <String, dynamic>{
      'total_sp': instance.totalSP,
      'unallocated_sp': instance.unallocatedSP,
      'skills': instance.skills,
    };

_CharacterSkillItem _$CharacterSkillItemFromJson(Map<String, dynamic> json) =>
    _CharacterSkillItem(
      activeSkillLevel: (json['active_skill_level'] as num).toInt(),
      skillID: (json['skill_id'] as num).toInt(),
      skillpointsInSkill: (json['skillpoints_in_skill'] as num).toInt(),
      trainedSkillLevel: (json['trained_skill_level'] as num).toInt(),
    );

Map<String, dynamic> _$CharacterSkillItemToJson(_CharacterSkillItem instance) =>
    <String, dynamic>{
      'active_skill_level': instance.activeSkillLevel,
      'skill_id': instance.skillID,
      'skillpoints_in_skill': instance.skillpointsInSkill,
      'trained_skill_level': instance.trainedSkillLevel,
    };
