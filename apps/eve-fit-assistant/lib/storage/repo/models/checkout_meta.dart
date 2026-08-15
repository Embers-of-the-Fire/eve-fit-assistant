import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_meta.freezed.dart";
part "checkout_meta.g.dart";

/// Individual checkout metadata (checkouts/{id}/metadata.json).
///
/// schema.md §3.11
@freezed
abstract class CheckoutMeta with _$CheckoutMeta {
  const factory CheckoutMeta({
    required int schemaVersion,
    required String channel,
    required String resourceSnapshotHash,
    required String serverId,
    required String createdAt,
    @Default(IMap<String, String>.empty()) IMap<String, String> name,
    @Default("") String gameBuild,
    @Default("") String gameVersion,
    @Default("") String region,
    @Default("") String sync,
    @Default("") String branch,
  }) = _CheckoutMeta;

  factory CheckoutMeta.fromJson(Map<String, dynamic> json) => _$CheckoutMetaFromJson(json);
}
