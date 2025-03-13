// ignore_for_file: invalid_annotation_target

import 'dart:convert';

import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'skills.freezed.dart';
part 'skills.g.dart';

@freezed
abstract class CharacterSkills with _$CharacterSkills {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CharacterSkills({
    @JsonKey(name: 'total_sp') required int totalSP,
    @JsonKey(name: 'unallocated_sp') required int unallocatedSP,
    required List<CharacterSkillItem> skills,
  }) = _CharacterSkills;

  factory CharacterSkills.fromJson(Map<String, dynamic> json) => _$CharacterSkillsFromJson(json);
}

@freezed
abstract class CharacterSkillItem with _$CharacterSkillItem {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory CharacterSkillItem({
    required int activeSkillLevel,
    @JsonKey(name: 'skill_id') required int skillID,
    required int skillpointsInSkill,
    required int trainedSkillLevel,
  }) = _CharacterSkillItem;

  factory CharacterSkillItem.fromJson(Map<String, dynamic> json) =>
      _$CharacterSkillItemFromJson(json);
}

Future<CharacterSkills> characterSkills() async {
  final characterID = (await EsiDataStorage().getCharacter())!.characterID;
  final url =
      Uri.parse('${esiUrl(Preference().esiAuthServer)}/latest/characters/$characterID/skills')
          .replace(
    queryParameters: {
      'token': (await EsiAuth().getTokensAuthorized())!.accessToken,
      'datasource': Preference().esiAuthServer.datasourceText,
    },
  );
  final response = await http.get(url);
  return CharacterSkills.fromJson(jsonDecode(response.body));
}
