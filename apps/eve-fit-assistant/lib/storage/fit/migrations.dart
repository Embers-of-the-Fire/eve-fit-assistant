import "package:eve_fit_assistant/storage/repo/migration/action/legacy_utils.dart";

/// Upgrades a legacy (pre-checkout) fit metadata JSON map to the current shape.
///
/// Legacy metadata carries `bundleId` and `bundleSnapshot` instead of
/// `checkoutRef`. The bundle snapshot may be a plain checkout id string or an
/// object describing the bundle; only the string form yields a checkout id.
///
/// The upgrade is idempotent: metadata that already has `checkoutRef` is
/// returned unchanged.
Map<String, dynamic> upgradeLegacyFitMetadataJson(Map<String, dynamic> metadata) {
  if (metadata["checkoutRef"] != null) {
    return metadata;
  }

  final bundleSnapshot = metadata["bundleSnapshot"];
  final bundleId = metadata["bundleId"];
  final checkoutRef = <String, dynamic>{
    "checkoutId": bundleSnapshot is String ? bundleSnapshot : "",
    "serverId": bundleId is String ? serverIdFromBundleId(bundleId) : "",
  };

  return Map<String, dynamic>.from(metadata)
    ..["checkoutRef"] = checkoutRef
    ..remove("bundleId")
    ..remove("bundleSnapshot");
}

/// Upgrades a legacy fit storage JSON map (the inner `fit` payload) to the
/// current shape by upgrading its metadata.
Map<String, dynamic> upgradeLegacyFitStorageJson(Map<String, dynamic> fitJson) {
  final metadata = fitJson["metadata"];
  if (metadata is! Map<String, dynamic>) {
    return fitJson;
  }
  return Map<String, dynamic>.from(fitJson)..["metadata"] = upgradeLegacyFitMetadataJson(metadata);
}
