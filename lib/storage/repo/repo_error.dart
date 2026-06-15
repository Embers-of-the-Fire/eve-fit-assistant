import "package:freezed_annotation/freezed_annotation.dart";

part "repo_error.freezed.dart";

@freezed
sealed class RepoError with _$RepoError {
  const factory RepoError.network({required String message, Object? cause}) = RepoErrorNetwork;
  const factory RepoError.storage({required String message, Object? cause}) = RepoErrorStorage;
  const factory RepoError.corrupt({required String message, required String filePath}) =
      RepoErrorCorrupt;
  const factory RepoError.remoteData({required String message, String? remotePath}) =
      RepoErrorRemoteData;
}
