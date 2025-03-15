// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VerifyResponse _$VerifyResponseFromJson(Map<String, dynamic> json) =>
    _VerifyResponse(
      characterID: (json['CharacterID'] as num).toInt(),
      characterName: json['CharacterName'] as String?,
    );

Map<String, dynamic> _$VerifyResponseToJson(_VerifyResponse instance) =>
    <String, dynamic>{
      'CharacterID': instance.characterID,
      'CharacterName': instance.characterName,
    };
