import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "active.freezed.dart";
part "active.g.dart";

@freezed
abstract class Active with _$Active {
  const factory Active({
    required int schemaVersion,
    required String checkoutId,
    required String activatedAt,
    required String serverId,
    required GameMetadata metadata,
    String? branchId,
  }) = _Active;

  factory Active.fromJson(Map<String, dynamic> json) => _$ActiveFromJson(json);
}
