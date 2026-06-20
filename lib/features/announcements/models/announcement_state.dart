import "package:freezed_annotation/freezed_annotation.dart";

part "announcement_state.freezed.dart";
part "announcement_state.g.dart";

@freezed
abstract class AnnouncementState with _$AnnouncementState {
  const factory AnnouncementState({
    @Default(1) int schemaVersion,
    @Default(<String>[]) List<String> readIds,
    @Default(<String>[]) List<String> dismissedIds,
    String? lastSeenAppVersion,
  }) = _AnnouncementState;

  factory AnnouncementState.initial() => const AnnouncementState();

  factory AnnouncementState.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementStateFromJson(json);
}
