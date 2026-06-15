import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "branch.freezed.dart";
part "branch.g.dart";

@freezed
abstract class Branch with _$Branch {
  const factory Branch({
    required int schemaVersion,
    required String id,
    required String checkout,
    required String serverId,
    required GameMetadata metadata,
    required BranchSource source,
    @Default(IMap<String, String>.empty()) IMap<String, String> name,
    @Default(false) bool pinned,
    @Default(IList<ReflogEntry>.empty()) IList<ReflogEntry> reflog,
    @Default(IMap<String, Diff>.empty()) IMap<String, Diff> diffs,
  }) = _Branch;

  factory Branch.fromJson(Map<String, dynamic> json) => _$BranchFromJson(json);
}

@freezed
abstract class BranchSource with _$BranchSource {
  const factory BranchSource({required String channel, String? remoteCheckoutId}) = _BranchSource;

  factory BranchSource.fromJson(Map<String, dynamic> json) => _$BranchSourceFromJson(json);
}
