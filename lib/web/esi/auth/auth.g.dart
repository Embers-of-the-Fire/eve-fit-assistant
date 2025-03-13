// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EsiAuthResponse _$EsiAuthResponseFromJson(Map<String, dynamic> json) =>
    _EsiAuthResponse(
      accessToken: json['access_token'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
      refreshToken: json['refresh_token'] as String,
    );

Map<String, dynamic> _$EsiAuthResponseToJson(_EsiAuthResponse instance) =>
    <String, dynamic>{
      'access_token': instance.accessToken,
      'expires_in': instance.expiresIn,
      'refresh_token': instance.refreshToken,
    };

_EsiAuthTokens _$EsiAuthTokensFromJson(Map<String, dynamic> json) =>
    _EsiAuthTokens(
      accessToken: json['accessToken'] as String,
      expiresTimestamp: (json['expiresTimestamp'] as num).toInt(),
      refreshToken: json['refreshToken'] as String,
      server: $enumDecode(_$EsiAuthServerEnumMap, json['server']),
    );

Map<String, dynamic> _$EsiAuthTokensToJson(_EsiAuthTokens instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'expiresTimestamp': instance.expiresTimestamp,
      'refreshToken': instance.refreshToken,
      'server': _$EsiAuthServerEnumMap[instance.server]!,
    };

const _$EsiAuthServerEnumMap = {
  EsiAuthServer.tranquility: 0,
  EsiAuthServer.serenity: 1,
};
