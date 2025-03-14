// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'skills.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CharacterSkills {
  @JsonKey(name: 'total_sp')
  int get totalSP;
  @JsonKey(name: 'unallocated_sp')
  int get unallocatedSP;
  List<CharacterSkillItem> get skills;

  /// Create a copy of CharacterSkills
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CharacterSkillsCopyWith<CharacterSkills> get copyWith =>
      _$CharacterSkillsCopyWithImpl<CharacterSkills>(this as CharacterSkills, _$identity);

  /// Serializes this CharacterSkills to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CharacterSkills &&
            (identical(other.totalSP, totalSP) || other.totalSP == totalSP) &&
            (identical(other.unallocatedSP, unallocatedSP) ||
                other.unallocatedSP == unallocatedSP) &&
            const DeepCollectionEquality().equals(other.skills, skills));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, totalSP, unallocatedSP, const DeepCollectionEquality().hash(skills));

  @override
  String toString() {
    return 'CharacterSkills(totalSP: $totalSP, unallocatedSP: $unallocatedSP, skills: $skills)';
  }
}

/// @nodoc
abstract mixin class $CharacterSkillsCopyWith<$Res> {
  factory $CharacterSkillsCopyWith(CharacterSkills value, $Res Function(CharacterSkills) _then) =
      _$CharacterSkillsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'total_sp') int totalSP,
      @JsonKey(name: 'unallocated_sp') int unallocatedSP,
      List<CharacterSkillItem> skills});
}

/// @nodoc
class _$CharacterSkillsCopyWithImpl<$Res> implements $CharacterSkillsCopyWith<$Res> {
  _$CharacterSkillsCopyWithImpl(this._self, this._then);

  final CharacterSkills _self;
  final $Res Function(CharacterSkills) _then;

  /// Create a copy of CharacterSkills
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalSP = null,
    Object? unallocatedSP = null,
    Object? skills = null,
  }) {
    return _then(_self.copyWith(
      totalSP: null == totalSP
          ? _self.totalSP
          : totalSP // ignore: cast_nullable_to_non_nullable
              as int,
      unallocatedSP: null == unallocatedSP
          ? _self.unallocatedSP
          : unallocatedSP // ignore: cast_nullable_to_non_nullable
              as int,
      skills: null == skills
          ? _self.skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<CharacterSkillItem>,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _CharacterSkills implements CharacterSkills {
  const _CharacterSkills(
      {@JsonKey(name: 'total_sp') required this.totalSP,
      @JsonKey(name: 'unallocated_sp') required this.unallocatedSP,
      required final List<CharacterSkillItem> skills})
      : _skills = skills;
  factory _CharacterSkills.fromJson(Map<String, dynamic> json) => _$CharacterSkillsFromJson(json);

  @override
  @JsonKey(name: 'total_sp')
  final int totalSP;
  @override
  @JsonKey(name: 'unallocated_sp')
  final int unallocatedSP;
  final List<CharacterSkillItem> _skills;
  @override
  List<CharacterSkillItem> get skills {
    if (_skills is EqualUnmodifiableListView) return _skills;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_skills);
  }

  /// Create a copy of CharacterSkills
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CharacterSkillsCopyWith<_CharacterSkills> get copyWith =>
      __$CharacterSkillsCopyWithImpl<_CharacterSkills>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CharacterSkillsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CharacterSkills &&
            (identical(other.totalSP, totalSP) || other.totalSP == totalSP) &&
            (identical(other.unallocatedSP, unallocatedSP) ||
                other.unallocatedSP == unallocatedSP) &&
            const DeepCollectionEquality().equals(other._skills, _skills));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, totalSP, unallocatedSP, const DeepCollectionEquality().hash(_skills));

  @override
  String toString() {
    return 'CharacterSkills(totalSP: $totalSP, unallocatedSP: $unallocatedSP, skills: $skills)';
  }
}

/// @nodoc
abstract mixin class _$CharacterSkillsCopyWith<$Res> implements $CharacterSkillsCopyWith<$Res> {
  factory _$CharacterSkillsCopyWith(_CharacterSkills value, $Res Function(_CharacterSkills) _then) =
      __$CharacterSkillsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'total_sp') int totalSP,
      @JsonKey(name: 'unallocated_sp') int unallocatedSP,
      List<CharacterSkillItem> skills});
}

/// @nodoc
class __$CharacterSkillsCopyWithImpl<$Res> implements _$CharacterSkillsCopyWith<$Res> {
  __$CharacterSkillsCopyWithImpl(this._self, this._then);

  final _CharacterSkills _self;
  final $Res Function(_CharacterSkills) _then;

  /// Create a copy of CharacterSkills
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? totalSP = null,
    Object? unallocatedSP = null,
    Object? skills = null,
  }) {
    return _then(_CharacterSkills(
      totalSP: null == totalSP
          ? _self.totalSP
          : totalSP // ignore: cast_nullable_to_non_nullable
              as int,
      unallocatedSP: null == unallocatedSP
          ? _self.unallocatedSP
          : unallocatedSP // ignore: cast_nullable_to_non_nullable
              as int,
      skills: null == skills
          ? _self._skills
          : skills // ignore: cast_nullable_to_non_nullable
              as List<CharacterSkillItem>,
    ));
  }
}

/// @nodoc
mixin _$CharacterSkillItem {
  int get activeSkillLevel;
  @JsonKey(name: 'skill_id')
  int get skillID;
  int get skillpointsInSkill;
  int get trainedSkillLevel;

  /// Create a copy of CharacterSkillItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CharacterSkillItemCopyWith<CharacterSkillItem> get copyWith =>
      _$CharacterSkillItemCopyWithImpl<CharacterSkillItem>(this as CharacterSkillItem, _$identity);

  /// Serializes this CharacterSkillItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CharacterSkillItem &&
            (identical(other.activeSkillLevel, activeSkillLevel) ||
                other.activeSkillLevel == activeSkillLevel) &&
            (identical(other.skillID, skillID) || other.skillID == skillID) &&
            (identical(other.skillpointsInSkill, skillpointsInSkill) ||
                other.skillpointsInSkill == skillpointsInSkill) &&
            (identical(other.trainedSkillLevel, trainedSkillLevel) ||
                other.trainedSkillLevel == trainedSkillLevel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, activeSkillLevel, skillID, skillpointsInSkill, trainedSkillLevel);

  @override
  String toString() {
    return 'CharacterSkillItem(activeSkillLevel: $activeSkillLevel, skillID: $skillID, skillpointsInSkill: $skillpointsInSkill, trainedSkillLevel: $trainedSkillLevel)';
  }
}

/// @nodoc
abstract mixin class $CharacterSkillItemCopyWith<$Res> {
  factory $CharacterSkillItemCopyWith(
          CharacterSkillItem value, $Res Function(CharacterSkillItem) _then) =
      _$CharacterSkillItemCopyWithImpl;
  @useResult
  $Res call(
      {int activeSkillLevel,
      @JsonKey(name: 'skill_id') int skillID,
      int skillpointsInSkill,
      int trainedSkillLevel});
}

/// @nodoc
class _$CharacterSkillItemCopyWithImpl<$Res> implements $CharacterSkillItemCopyWith<$Res> {
  _$CharacterSkillItemCopyWithImpl(this._self, this._then);

  final CharacterSkillItem _self;
  final $Res Function(CharacterSkillItem) _then;

  /// Create a copy of CharacterSkillItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? activeSkillLevel = null,
    Object? skillID = null,
    Object? skillpointsInSkill = null,
    Object? trainedSkillLevel = null,
  }) {
    return _then(_self.copyWith(
      activeSkillLevel: null == activeSkillLevel
          ? _self.activeSkillLevel
          : activeSkillLevel // ignore: cast_nullable_to_non_nullable
              as int,
      skillID: null == skillID
          ? _self.skillID
          : skillID // ignore: cast_nullable_to_non_nullable
              as int,
      skillpointsInSkill: null == skillpointsInSkill
          ? _self.skillpointsInSkill
          : skillpointsInSkill // ignore: cast_nullable_to_non_nullable
              as int,
      trainedSkillLevel: null == trainedSkillLevel
          ? _self.trainedSkillLevel
          : trainedSkillLevel // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _CharacterSkillItem implements CharacterSkillItem {
  const _CharacterSkillItem(
      {required this.activeSkillLevel,
      @JsonKey(name: 'skill_id') required this.skillID,
      required this.skillpointsInSkill,
      required this.trainedSkillLevel});
  factory _CharacterSkillItem.fromJson(Map<String, dynamic> json) =>
      _$CharacterSkillItemFromJson(json);

  @override
  final int activeSkillLevel;
  @override
  @JsonKey(name: 'skill_id')
  final int skillID;
  @override
  final int skillpointsInSkill;
  @override
  final int trainedSkillLevel;

  /// Create a copy of CharacterSkillItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CharacterSkillItemCopyWith<_CharacterSkillItem> get copyWith =>
      __$CharacterSkillItemCopyWithImpl<_CharacterSkillItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CharacterSkillItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CharacterSkillItem &&
            (identical(other.activeSkillLevel, activeSkillLevel) ||
                other.activeSkillLevel == activeSkillLevel) &&
            (identical(other.skillID, skillID) || other.skillID == skillID) &&
            (identical(other.skillpointsInSkill, skillpointsInSkill) ||
                other.skillpointsInSkill == skillpointsInSkill) &&
            (identical(other.trainedSkillLevel, trainedSkillLevel) ||
                other.trainedSkillLevel == trainedSkillLevel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, activeSkillLevel, skillID, skillpointsInSkill, trainedSkillLevel);

  @override
  String toString() {
    return 'CharacterSkillItem(activeSkillLevel: $activeSkillLevel, skillID: $skillID, skillpointsInSkill: $skillpointsInSkill, trainedSkillLevel: $trainedSkillLevel)';
  }
}

/// @nodoc
abstract mixin class _$CharacterSkillItemCopyWith<$Res>
    implements $CharacterSkillItemCopyWith<$Res> {
  factory _$CharacterSkillItemCopyWith(
          _CharacterSkillItem value, $Res Function(_CharacterSkillItem) _then) =
      __$CharacterSkillItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int activeSkillLevel,
      @JsonKey(name: 'skill_id') int skillID,
      int skillpointsInSkill,
      int trainedSkillLevel});
}

/// @nodoc
class __$CharacterSkillItemCopyWithImpl<$Res> implements _$CharacterSkillItemCopyWith<$Res> {
  __$CharacterSkillItemCopyWithImpl(this._self, this._then);

  final _CharacterSkillItem _self;
  final $Res Function(_CharacterSkillItem) _then;

  /// Create a copy of CharacterSkillItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? activeSkillLevel = null,
    Object? skillID = null,
    Object? skillpointsInSkill = null,
    Object? trainedSkillLevel = null,
  }) {
    return _then(_CharacterSkillItem(
      activeSkillLevel: null == activeSkillLevel
          ? _self.activeSkillLevel
          : activeSkillLevel // ignore: cast_nullable_to_non_nullable
              as int,
      skillID: null == skillID
          ? _self.skillID
          : skillID // ignore: cast_nullable_to_non_nullable
              as int,
      skillpointsInSkill: null == skillpointsInSkill
          ? _self.skillpointsInSkill
          : skillpointsInSkill // ignore: cast_nullable_to_non_nullable
              as int,
      trainedSkillLevel: null == trainedSkillLevel
          ? _self.trainedSkillLevel
          : trainedSkillLevel // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
