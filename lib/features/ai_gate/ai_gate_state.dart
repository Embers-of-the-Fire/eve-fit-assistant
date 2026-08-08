import "package:freezed_annotation/freezed_annotation.dart";

part "ai_gate_state.freezed.dart";

/// Gate state of the AI assistant feature.
///
/// The hub page (and every AI surface wrapped by `AiFeatureGate`) renders
/// exactly one of these states; the actual feature content is only reachable
/// in [AiGateReady].
@freezed
sealed class AiGateState with _$AiGateState {
  /// First contact: the user has not acknowledged the AI service notice yet.
  const factory AiGateState.disclaimer() = AiGateDisclaimer;

  /// Notice acknowledged, but AI support is still disabled.
  const factory AiGateState.enable() = AiGateEnable;

  /// Resolving agent database availability.
  const factory AiGateState.loading() = AiGateLoading;

  /// The agent database is being downloaded (bytes progress).
  const factory AiGateState.downloading({required int downloadedBytes, required int totalBytes}) =
      AiGateDownloading;

  /// The agent database download failed and can be retried.
  const factory AiGateState.downloadFailed({required String message}) = AiGateDownloadFailed;

  /// AI is enabled but no checkout exists; the user must set up data first.
  const factory AiGateState.dataRequiredNoCheckout() = AiGateDataRequiredNoCheckout;

  /// AI is enabled and a checkout exists, but its data predates the agent
  /// database resource; a data update is required.
  const factory AiGateState.dataRequiredUpdate() = AiGateDataRequiredUpdate;

  /// AI is enabled and the checkout carries the agent database resource, but
  /// the blob is not downloaded yet.
  const factory AiGateState.dataRequiredDownload() = AiGateDataRequiredDownload;

  /// AI is enabled and the agent database is present; show the feature.
  const factory AiGateState.ready() = AiGateReady;
}
