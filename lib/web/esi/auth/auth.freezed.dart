// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EsiAuthResponse {
  @JsonKey(name: 'access_token')
  String get accessToken;
  @JsonKey(name: 'expires_in')
  int get expiresIn;
  @JsonKey(name: 'refresh_token')
  String get refreshToken;

  /// Create a copy of EsiAuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EsiAuthResponseCopyWith<EsiAuthResponse> get copyWith =>
      _$EsiAuthResponseCopyWithImpl<EsiAuthResponse>(
          this as EsiAuthResponse, _$identity);

  /// Serializes this EsiAuthResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EsiAuthResponse &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, accessToken, expiresIn, refreshToken);

  @override
  String toString() {
    return 'EsiAuthResponse(accessToken: $accessToken, expiresIn: $expiresIn, refreshToken: $refreshToken)';
  }
}

/// @nodoc
abstract mixin class $EsiAuthResponseCopyWith<$Res> {
  factory $EsiAuthResponseCopyWith(
          EsiAuthResponse value, $Res Function(EsiAuthResponse) _then) =
      _$EsiAuthResponseCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'access_token') String accessToken,
      @JsonKey(name: 'expires_in') int expiresIn,
      @JsonKey(name: 'refresh_token') String refreshToken});
}

/// @nodoc
class _$EsiAuthResponseCopyWithImpl<$Res>
    implements $EsiAuthResponseCopyWith<$Res> {
  _$EsiAuthResponseCopyWithImpl(this._self, this._then);

  final EsiAuthResponse _self;
  final $Res Function(EsiAuthResponse) _then;

  /// Create a copy of EsiAuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accessToken = null,
    Object? expiresIn = null,
    Object? refreshToken = null,
  }) {
    return _then(_self.copyWith(
      accessToken: null == accessToken
          ? _self.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresIn: null == expiresIn
          ? _self.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      refreshToken: null == refreshToken
          ? _self.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _EsiAuthResponse implements EsiAuthResponse {
  const _EsiAuthResponse(
      {@JsonKey(name: 'access_token') required this.accessToken,
      @JsonKey(name: 'expires_in') required this.expiresIn,
      @JsonKey(name: 'refresh_token') required this.refreshToken});
  factory _EsiAuthResponse.fromJson(Map<String, dynamic> json) =>
      _$EsiAuthResponseFromJson(json);

  @override
  @JsonKey(name: 'access_token')
  final String accessToken;
  @override
  @JsonKey(name: 'expires_in')
  final int expiresIn;
  @override
  @JsonKey(name: 'refresh_token')
  final String refreshToken;

  /// Create a copy of EsiAuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EsiAuthResponseCopyWith<_EsiAuthResponse> get copyWith =>
      __$EsiAuthResponseCopyWithImpl<_EsiAuthResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$EsiAuthResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EsiAuthResponse &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.expiresIn, expiresIn) ||
                other.expiresIn == expiresIn) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, accessToken, expiresIn, refreshToken);

  @override
  String toString() {
    return 'EsiAuthResponse(accessToken: $accessToken, expiresIn: $expiresIn, refreshToken: $refreshToken)';
  }
}

/// @nodoc
abstract mixin class _$EsiAuthResponseCopyWith<$Res>
    implements $EsiAuthResponseCopyWith<$Res> {
  factory _$EsiAuthResponseCopyWith(
          _EsiAuthResponse value, $Res Function(_EsiAuthResponse) _then) =
      __$EsiAuthResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'access_token') String accessToken,
      @JsonKey(name: 'expires_in') int expiresIn,
      @JsonKey(name: 'refresh_token') String refreshToken});
}

/// @nodoc
class __$EsiAuthResponseCopyWithImpl<$Res>
    implements _$EsiAuthResponseCopyWith<$Res> {
  __$EsiAuthResponseCopyWithImpl(this._self, this._then);

  final _EsiAuthResponse _self;
  final $Res Function(_EsiAuthResponse) _then;

  /// Create a copy of EsiAuthResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? accessToken = null,
    Object? expiresIn = null,
    Object? refreshToken = null,
  }) {
    return _then(_EsiAuthResponse(
      accessToken: null == accessToken
          ? _self.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresIn: null == expiresIn
          ? _self.expiresIn
          : expiresIn // ignore: cast_nullable_to_non_nullable
              as int,
      refreshToken: null == refreshToken
          ? _self.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$EsiAuthTokens {
  String get accessToken;
  int get expiresTimestamp;
  String get refreshToken;

  /// Create a copy of EsiAuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EsiAuthTokensCopyWith<EsiAuthTokens> get copyWith =>
      _$EsiAuthTokensCopyWithImpl<EsiAuthTokens>(
          this as EsiAuthTokens, _$identity);

  /// Serializes this EsiAuthTokens to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EsiAuthTokens &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.expiresTimestamp, expiresTimestamp) ||
                other.expiresTimestamp == expiresTimestamp) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, accessToken, expiresTimestamp, refreshToken);

  @override
  String toString() {
    return 'EsiAuthTokens(accessToken: $accessToken, expiresTimestamp: $expiresTimestamp, refreshToken: $refreshToken)';
  }
}

/// @nodoc
abstract mixin class $EsiAuthTokensCopyWith<$Res> {
  factory $EsiAuthTokensCopyWith(
          EsiAuthTokens value, $Res Function(EsiAuthTokens) _then) =
      _$EsiAuthTokensCopyWithImpl;
  @useResult
  $Res call({String accessToken, int expiresTimestamp, String refreshToken});
}

/// @nodoc
class _$EsiAuthTokensCopyWithImpl<$Res>
    implements $EsiAuthTokensCopyWith<$Res> {
  _$EsiAuthTokensCopyWithImpl(this._self, this._then);

  final EsiAuthTokens _self;
  final $Res Function(EsiAuthTokens) _then;

  /// Create a copy of EsiAuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? accessToken = null,
    Object? expiresTimestamp = null,
    Object? refreshToken = null,
  }) {
    return _then(_self.copyWith(
      accessToken: null == accessToken
          ? _self.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresTimestamp: null == expiresTimestamp
          ? _self.expiresTimestamp
          : expiresTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      refreshToken: null == refreshToken
          ? _self.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _EsiAuthTokens extends EsiAuthTokens {
  const _EsiAuthTokens(
      {required this.accessToken,
      required this.expiresTimestamp,
      required this.refreshToken})
      : super._();
  factory _EsiAuthTokens.fromJson(Map<String, dynamic> json) =>
      _$EsiAuthTokensFromJson(json);

  @override
  final String accessToken;
  @override
  final int expiresTimestamp;
  @override
  final String refreshToken;

  /// Create a copy of EsiAuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EsiAuthTokensCopyWith<_EsiAuthTokens> get copyWith =>
      __$EsiAuthTokensCopyWithImpl<_EsiAuthTokens>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$EsiAuthTokensToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EsiAuthTokens &&
            (identical(other.accessToken, accessToken) ||
                other.accessToken == accessToken) &&
            (identical(other.expiresTimestamp, expiresTimestamp) ||
                other.expiresTimestamp == expiresTimestamp) &&
            (identical(other.refreshToken, refreshToken) ||
                other.refreshToken == refreshToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, accessToken, expiresTimestamp, refreshToken);

  @override
  String toString() {
    return 'EsiAuthTokens(accessToken: $accessToken, expiresTimestamp: $expiresTimestamp, refreshToken: $refreshToken)';
  }
}

/// @nodoc
abstract mixin class _$EsiAuthTokensCopyWith<$Res>
    implements $EsiAuthTokensCopyWith<$Res> {
  factory _$EsiAuthTokensCopyWith(
          _EsiAuthTokens value, $Res Function(_EsiAuthTokens) _then) =
      __$EsiAuthTokensCopyWithImpl;
  @override
  @useResult
  $Res call({String accessToken, int expiresTimestamp, String refreshToken});
}

/// @nodoc
class __$EsiAuthTokensCopyWithImpl<$Res>
    implements _$EsiAuthTokensCopyWith<$Res> {
  __$EsiAuthTokensCopyWithImpl(this._self, this._then);

  final _EsiAuthTokens _self;
  final $Res Function(_EsiAuthTokens) _then;

  /// Create a copy of EsiAuthTokens
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? accessToken = null,
    Object? expiresTimestamp = null,
    Object? refreshToken = null,
  }) {
    return _then(_EsiAuthTokens(
      accessToken: null == accessToken
          ? _self.accessToken
          : accessToken // ignore: cast_nullable_to_non_nullable
              as String,
      expiresTimestamp: null == expiresTimestamp
          ? _self.expiresTimestamp
          : expiresTimestamp // ignore: cast_nullable_to_non_nullable
              as int,
      refreshToken: null == refreshToken
          ? _self.refreshToken
          : refreshToken // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
