import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/damage_profile.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'damage_profile.freezed.dart';
part 'damage_profile.g.dart';

@freezed
class DamageProfile with _$DamageProfile {
  const factory DamageProfile({
    required double em,
    required double thermal,
    required double kinetic,
    required double explosive,
  }) = _DamageProfile;

  factory DamageProfile.fromJson(Map<String, dynamic> json) => _$DamageProfileFromJson(json);

  static const defaultProfile =
      DamageProfile(em: 0.25, thermal: 0.25, kinetic: 0.25, explosive: 0.25);

  factory DamageProfile._fromRaw(DamageProfiles_DamageProfile buffer) => DamageProfile(
        em: buffer.em,
        thermal: buffer.thermal,
        kinetic: buffer.kinetic,
        explosive: buffer.explosive,
      );
}

class DamageProfileItem {
  final String _name;
  final DamageProfile _damageProfile;

  String get name => _name;

  DamageProfile get damageProfile => _damageProfile;

  const DamageProfileItem._private(this._name, this._damageProfile);

  factory DamageProfileItem._fromRaw(DamageProfiles_DamageProfile raw) =>
      DamageProfileItem._private(raw.name, DamageProfile._fromRaw(raw));
}

class DamageProfileGroup {
  final String _name;
  final List<DamageProfileItem> _profiles;

  String get name => _name;

  List<DamageProfileItem> get profiles => _profiles;

  const DamageProfileGroup._private(this._name, this._profiles);

  factory DamageProfileGroup._fromRaw(DamageProfiles_DamageProfileGroup raw) {
    final profiles = raw.profiles.map(DamageProfileItem._fromRaw).toList();
    return DamageProfileGroup._private(raw.name, profiles);
  }

  static Map<String, DamageProfileGroup> _fromBuffer(Uint8List buffer) {
    final raw = DamageProfiles.fromBuffer(buffer);
    return Map.fromEntries(
        raw.groups.map(DamageProfileGroup._fromRaw).map((e) => MapEntry(e.name, e)));
  }

  static Future<ReadonlyMap<String, DamageProfileGroup>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/damage_profile.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
