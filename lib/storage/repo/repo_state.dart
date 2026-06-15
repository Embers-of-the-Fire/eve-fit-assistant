import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/repo_error.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "repo_state.freezed.dart";

@freezed
sealed class RepoState with _$RepoState {
  const factory RepoState.uninitialized() = RepoStateUninitialized;

  const factory RepoState.initializing() = RepoStateInitializing;

  const factory RepoState.active({required Active active}) = RepoStateActive;

  const factory RepoState.error({required RepoError error}) = RepoStateError;
}
