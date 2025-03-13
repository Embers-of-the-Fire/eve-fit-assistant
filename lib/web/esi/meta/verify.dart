// ignore_for_file: invalid_annotation_target

import 'dart:convert';

import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/web/esi/auth/auth.dart';
import 'package:eve_fit_assistant/web/esi/storage/esi.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'verify.freezed.dart';
part 'verify.g.dart';

@freezed
abstract class VerifyResponse with _$VerifyResponse {
  @JsonSerializable()
  const factory VerifyResponse({
    @JsonKey(name: 'CharacterID') required int characterID,
    @JsonKey(name: 'CharacterName') String? characterName,
  }) = _VerifyResponse;

  factory VerifyResponse.fromJson(Map<String, dynamic> json) => _$VerifyResponseFromJson(json);
}

Future<VerifyResponse> verify() async {
  final url = Uri.parse('${esiUrl(Preference().esiAuthServer)}/verify/').replace(queryParameters: {
    'datasource': Preference().esiAuthServer.datasourceText,
    'token': (await EsiAuth().getTokensAuthorized())!.accessToken,
  });
  final response = await http.get(url);
  return VerifyResponse.fromJson(jsonDecode(response.body));
}
