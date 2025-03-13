part of 'esi.dart';

@freezed
abstract class Character with _$Character {
  const factory Character({
    required int characterID,
    required String? characterName,
  }) = _Character;

  const Character._();

  static Future<Character> init() async {
    final verifyResponse = await verify();
    return Character(
      characterID: verifyResponse.characterID,
      characterName: verifyResponse.characterName,
    );
  }
}
