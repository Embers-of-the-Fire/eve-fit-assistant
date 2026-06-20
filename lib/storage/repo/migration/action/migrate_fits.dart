import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/legacy_utils.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/migrate_runner.dart";

class MigrateFits {
  const MigrateFits();

  Future<MigrateFitsResult> migrate({
    required String sourceFittingsPath,
    required String destinationFittingsPath,
  }) async {
    final (:migrated, :skipped, :errors) = await MigrateRunner.run(
      sourceDirectory: sourceFittingsPath,
      destinationDirectory: destinationFittingsPath,
      needsUpgrade: _needsMigration,
      upgrade: _migrateFitRecord,
      onError: (exception, filePath) => warning("Failed to migrate fit file $filePath: $exception"),
    );
    return MigrateFitsResult(migrated: migrated, skipped: skipped, errors: errors);
  }

  bool _needsMigration(Map<String, dynamic> json) {
    final payload = json["fit"];
    if (payload is! Map<String, dynamic>) return false;
    final metadata = payload["metadata"];
    if (metadata is! Map<String, dynamic>) return false;
    return metadata["checkoutRef"] == null && metadata.containsKey("bundleSnapshot");
  }

  Map<String, dynamic> _migrateFitRecord(Map<String, dynamic> json) {
    final payload = json["fit"] as Map<String, dynamic>;
    final metadata = payload["metadata"] as Map<String, dynamic>;

    final bundleSnapshot = metadata["bundleSnapshot"];
    final checkoutId = bundleSnapshot is String ? bundleSnapshot : "";
    final bundleId = metadata["bundleId"];
    final serverId = bundleId is String ? serverIdFromBundleId(bundleId) : "";

    final checkoutRefJson = <String, dynamic>{"checkoutId": checkoutId, "serverId": serverId};

    final updatedMetadata = Map<String, dynamic>.from(metadata)
      ..["checkoutRef"] = checkoutRefJson
      ..remove("bundleId")
      ..remove("bundleSnapshot");

    final updatedPayload = Map<String, dynamic>.from(payload)..["metadata"] = updatedMetadata;

    return Map<String, dynamic>.from(json)
      ..["version"] = 2
      ..["fit"] = updatedPayload;
  }
}

class MigrateFitsResult {
  const MigrateFitsResult({required this.migrated, required this.skipped, required this.errors});

  factory MigrateFitsResult.fromJson(Map<String, dynamic> json) => MigrateFitsResult(
    migrated: json["migrated"] as int,
    skipped: json["skipped"] as int,
    errors: json["errors"] as int,
  );

  final int migrated;
  final int skipped;
  final int errors;

  Map<String, dynamic> toJson() => {"migrated": migrated, "skipped": skipped, "errors": errors};
}
