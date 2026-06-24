import "package:freezed_annotation/freezed_annotation.dart";

part "feedback_state.freezed.dart";
part "feedback_state.g.dart";

@freezed
abstract class FeedbackState with _$FeedbackState {
  const factory FeedbackState({
    @Default(1) int schemaVersion,
    @Default(0) int launchCount,
    DateTime? firstLaunchDate,
    DateTime? lastPromptDate,
    @Default(0) int remindedCount,
    @Default(false) bool feedbackGiven,
  }) = _FeedbackState;

  factory FeedbackState.initial() => const FeedbackState();

  factory FeedbackState.fromJson(Map<String, dynamic> json) => _$FeedbackStateFromJson(json);
}
