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
    );

Map<String, dynamic> _$EsiAuthTokensToJson(_EsiAuthTokens instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'expiresTimestamp': instance.expiresTimestamp,
      'refreshToken': instance.refreshToken,
    };

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$getEsiAuthStorageHash() => r'84fd0c7c6043631029f0293e6113560f9998fb5b';

/// See also [getEsiAuthStorage].
@ProviderFor(getEsiAuthStorage)
final getEsiAuthStorageProvider =
    AutoDisposeFutureProvider<EsiAuthData?>.internal(
  getEsiAuthStorage,
  name: r'getEsiAuthStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$getEsiAuthStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GetEsiAuthStorageRef = AutoDisposeFutureProviderRef<EsiAuthData?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
