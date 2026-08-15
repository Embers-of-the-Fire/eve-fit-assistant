import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "remote_app_release.freezed.dart";

/// A newer app release discovered from the remote release index.
@freezed
sealed class RemoteAppRelease with _$RemoteAppRelease {
  const factory RemoteAppRelease({
    required String releaseId,
    required String version,
    required String snapshotHash,
    required ReleaseIndex index,
  }) = _RemoteAppRelease;
}
