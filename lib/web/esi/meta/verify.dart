// ignore_for_file: invalid_annotation_target

import 'dart:convert';

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

Future<VerifyResponse> verify(String accessToken) async {
  final url = Uri.parse('https://esi.evetech.net/verify/').replace(queryParameters: {
    'datasource': 'tranquility',
    'token': accessToken,
  });
  final response = await http.get(url);
  return VerifyResponse.fromJson(jsonDecode(response.body));
}
