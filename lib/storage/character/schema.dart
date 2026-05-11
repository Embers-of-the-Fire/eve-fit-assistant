import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;

part "schema.freezed.dart";
part "schema.g.dart";

const predefinedMaxCharacterId = "predefined_all_5";
const predefinedAlphaMaxCharacterId = "predefined_alpha_max";
const predefinedZeroCharacterId = "predefined_all_0";

@freezed
abstract class CharacterBundleSnapshot with _$CharacterBundleSnapshot {
  const factory CharacterBundleSnapshot({
    required String bundleId,
    String? manifestHash,
    String? gameBuild,
    String? appVersion,
    int? generateTimestamp,
  }) = _CharacterBundleSnapshot;

  const CharacterBundleSnapshot._();

  factory CharacterBundleSnapshot.fromJson(Map<String, dynamic> json) =>
      _$CharacterBundleSnapshotFromJson(json);

  factory CharacterBundleSnapshot.fromBundleMetadata(BundleMetadata bundle) =>
      CharacterBundleSnapshot(
        bundleId: bundle.bundleId,
        manifestHash: bundle.metadata.latest.manifestHash,
        gameBuild: bundle.metadata.latest.gameBuild,
        appVersion: bundle.metadata.latest.appVersion,
        generateTimestamp: bundle.metadata.latest.generateTimestamp,
      );

  bool get hasComparableRevision =>
      manifestHash != null || generateTimestamp != null || gameBuild != null || appVersion != null;
}

@freezed
abstract class CharacterStorage with _$CharacterStorage {
  const factory CharacterStorage({
    required String characterId,
    required String name,
    required String description,

    /// DateTime.millisecondsSinceEpoch
    required int lastModified,

    required String bundleId,
    @JsonKey(readValue: readCharacterBundleSnapshot)
    required CharacterBundleSnapshot bundleSnapshot,
    required Map<int, int> skills,
  }) = _CharacterStorage;

  const CharacterStorage._();

  factory CharacterStorage.empty(CharacterMetadata metadata) => CharacterStorage(
    characterId: metadata.characterId,
    name: metadata.name,
    description: metadata.description,
    lastModified: metadata.lastModified,
    bundleId: metadata.bundleId,
    bundleSnapshot: metadata.bundleSnapshot,
    skills: {},
  );
  factory CharacterStorage.copyFrom(CharacterMetadata metadata, CharacterStorage other) =>
      CharacterStorage(
        characterId: metadata.characterId,
        name: metadata.name,
        description: metadata.description,
        lastModified: metadata.lastModified,
        bundleId: metadata.bundleId,
        bundleSnapshot: metadata.bundleSnapshot,
        skills: other.skills,
      );

  factory CharacterStorage.fromJson(Map<String, dynamic> json) => _$CharacterStorageFromJson(json);

  String get characterStoragePath => p.join(PathProvider.charactersPath, "$characterId.json");

  static String characterStoragePathForId(String characterId) =>
      p.join(PathProvider.charactersPath, "$characterId.json");
}

Object? readCharacterBundleSnapshot(Map<dynamic, dynamic> json, String key) {
  final snapshot = json[key];
  if (snapshot != null) {
    return snapshot;
  }

  final bundleId = json["bundleId"];
  if (bundleId is! String) {
    return null;
  }

  return <String, dynamic>{"bundleId": bundleId};
}
