import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_runner.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";

class MigrateCharacters {
  const MigrateCharacters();

  Future<MigrateCharactersResult> migrate({required String charactersPath}) async {
    final (:migrated, :skipped, :errors) = await MigrateRunner.run(
      directory: charactersPath,
      needsUpgrade: _needsMigration,
      upgrade: _migrateCharacterRecord,
      onError: (exception, filePath) =>
          warning("Failed to migrate character file $filePath: $exception"),
    );
    return MigrateCharactersResult(migrated: migrated, skipped: skipped, errors: errors);
  }

  bool _needsMigration(Map<String, dynamic> json) =>
      json["checkoutRef"] == null && json.containsKey("bundleSnapshot");

  Map<String, dynamic> _migrateCharacterRecord(Map<String, dynamic> json) {
    final bundleSnapshot = json["bundleSnapshot"];
    final checkoutId = bundleSnapshot is String ? bundleSnapshot : "";
    final bundleId = json["bundleId"];
    final serverId = bundleId is String ? serverIdFromBundleId(bundleId) : "";

    final checkoutRefJson = <String, dynamic>{
      "checkoutId": checkoutId,
      "serverId": serverId,
      "metadata": <String, dynamic>{"gameServer": "", "gameBuild": "", "gameVersion": ""},
    };

    return Map<String, dynamic>.from(json)
      ..["checkoutRef"] = checkoutRefJson
      ..remove("bundleId")
      ..remove("bundleSnapshot");
  }
}

class MigrateCharactersResult {
  const MigrateCharactersResult({
    required this.migrated,
    required this.skipped,
    required this.errors,
  });

  factory MigrateCharactersResult.fromJson(Map<String, dynamic> json) => MigrateCharactersResult(
    migrated: json["migrated"] as int,
    skipped: json["skipped"] as int,
    errors: json["errors"] as int,
  );

  final int migrated;
  final int skipped;
  final int errors;

  Map<String, dynamic> toJson() => {"migrated": migrated, "skipped": skipped, "errors": errors};
}
