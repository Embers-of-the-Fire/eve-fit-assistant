import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;

part "schema.freezed.dart";
part "schema.g.dart";

const predefinedMaxCharacterId = "predefined_all_5";
const predefinedAlphaMaxCharacterId = "predefined_alpha_max";
const predefinedZeroCharacterId = "predefined_all_0";

@freezed
abstract class CharacterStorage with _$CharacterStorage {
  const factory CharacterStorage({
    required String characterId,
    required String name,
    required String description,

    /// DateTime.millisecondsSinceEpoch
    required int lastModified,

    required CheckoutRef checkoutRef,
    required Map<int, int> skills,
  }) = _CharacterStorage;

  const CharacterStorage._();

  factory CharacterStorage.empty(CharacterMetadata metadata) => CharacterStorage(
    characterId: metadata.characterId,
    name: metadata.name,
    description: metadata.description,
    lastModified: metadata.lastModified,
    checkoutRef: metadata.checkoutRef,
    skills: {},
  );
  factory CharacterStorage.copyFrom(CharacterMetadata metadata, CharacterStorage other) =>
      CharacterStorage(
        characterId: metadata.characterId,
        name: metadata.name,
        description: metadata.description,
        lastModified: metadata.lastModified,
        checkoutRef: metadata.checkoutRef,
        skills: other.skills,
      );

  factory CharacterStorage.fromJson(Map<String, dynamic> json) => _$CharacterStorageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$CharacterStorageToJson(this as _CharacterStorage);

  String get characterStoragePath => p.join(PathProvider.charactersPath, "$characterId.json");

  static String characterStoragePathForId(String characterId) =>
      p.join(PathProvider.charactersPath, "$characterId.json");
}
