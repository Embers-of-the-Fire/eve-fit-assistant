import "dart:async";

import "package:eve_fit_assistant/features/ai_gate/ai_gate_state.dart";
import "package:eve_fit_assistant/storage/repo/agent_resource_db.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "ai_gate_controller.g.dart";

/// State machine behind the AI assistant feature gate.
///
/// Derives the gate state from settings (disclaimer acknowledgement, enable
/// flag), the active checkout, and agent database availability, and owns the
/// enable/download actions:
///
/// - [acknowledgeDisclaimer] records the one-time AI service notice.
/// - [enableAssistant] flips the global enable flag and, with an active
///   checkout whose agent database is not downloaded yet, downloads it
///   immediately with byte progress.
/// - [downloadAgentDb] (re)downloads the agent database blob on demand.
@riverpodSingleton
class AiGateController extends _$AiGateController {
  bool _downloadInFlight = false;

  @override
  AiGateState build() {
    final settings = ref.watch(appSettingServiceProvider);
    if (!settings.aiAssistantDisclaimerAcked) return const AiGateState.disclaimer();
    if (!settings.aiAssistantEnabled) return const AiGateState.enable();

    final active = ref.watch(activeCheckoutProvider);
    if (active.isNone()) return const AiGateState.dataRequiredNoCheckout();

    // A download in flight owns the state (downloading/failed) until it
    // finishes; availability refreshes must not stomp it.
    if (_downloadInFlight) return state;

    final availability = ref.watch(agentDbAvailabilityProvider);
    return availability.when(
      data: _stateForAvailability,
      error: (_, _) => const AiGateState.dataRequiredUpdate(),
      loading: () {
        final previous = availability.value;
        if (previous != null) return _stateForAvailability(previous);
        return const AiGateState.loading();
      },
    );
  }

  AiGateState _stateForAvailability(AgentDbAvailability availability) => switch (availability) {
    AgentDbAvailability.available => const AiGateState.ready(),
    AgentDbAvailability.downloadable => const AiGateState.dataRequiredDownload(),
    AgentDbAvailability.updateRequired => const AiGateState.dataRequiredUpdate(),
  };

  /// Records the one-time acknowledgement of the AI service notice.
  void acknowledgeDisclaimer() {
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(aiAssistantDisclaimerAcked: true));
  }

  /// Enables AI support globally.
  ///
  /// When a checkout is active but its agent database blob is missing, the
  /// database is downloaded first (with progress) before the gate opens.
  Future<void> enableAssistant() async {
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(aiAssistantDisclaimerAcked: true, aiAssistantEnabled: true));

    if (ref.read(activeCheckoutProvider).isNone()) return;
    final availability = await _resolveAvailability();
    if (availability == AgentDbAvailability.downloadable) {
      await downloadAgentDb();
    }
  }

  /// Disables AI support; the gate falls back to the enable state.
  void disableAssistant() {
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(aiAssistantEnabled: false));
  }

  Future<AgentDbAvailability?> _resolveAvailability() async {
    try {
      return await ref.read(agentDbAvailabilityProvider.future);
    } on Object {
      return null;
    }
  }

  /// Forces a fresh resolution and re-download of the agent database: drops
  /// any cached availability/service state (a warm-up may hold a stale error
  /// from before the blob landed) and fetches the blob again.
  Future<void> refreshAgentDb() async {
    ref
      ..invalidate(agentDbAvailabilityProvider)
      ..invalidate(agentResourceDbServiceProvider);
    await downloadAgentDb();
  }

  /// Downloads the agent database blob of the active checkout, reporting byte
  /// progress through [AiGateDownloading].
  ///
  /// Mirrors the on-demand fetcher's integrity rules: the payload is
  /// hash-verified before it is persisted into the content-addressed store.
  Future<void> downloadAgentDb() async {
    if (_downloadInFlight) return;
    _downloadInFlight = true;
    state = const AiGateState.downloading(downloadedBytes: 0, totalBytes: 0);
    try {
      final proxy = await ref.read(resourceBlobProxyProvider.future);
      final entry = proxy?.entry(kAgentResourceDbResourceId);
      if (entry == null) {
        state = const AiGateState.dataRequiredUpdate();
        return;
      }

      final identHash = RepoHash.hashIdent(kAgentResourceDbResourceId);
      final expectedBytes = entry.size.toInt();
      final result = await ref
          .read(remoteCatalogServiceProvider)
          .fetchBlob(
            identHash,
            entry.contentHash,
            onReceiveProgress: (received, total) {
              state = AiGateState.downloading(
                downloadedBytes: received,
                totalBytes: total > 0 ? total : expectedBytes,
              );
            },
          );
      if (result.isLeft()) {
        final err = result.getLeft().toNullable()!;
        state = AiGateState.downloadFailed(
          message: err is CatalogNetworkError ? err.message : "Failed to download agent database",
        );
        return;
      }

      final bytes = result.getRight().toNullable()!;
      if (RepoHash.hashContent(bytes) != entry.contentHash) {
        state = const AiGateState.downloadFailed(message: "Agent database content hash mismatch");
        return;
      }
      await ref
          .read(assetStoreProvider)
          .writeBlobUncheckedAt(RepoPaths.blobPath(identHash, entry.contentHash), bytes);

      // Let the availability/service providers observe the fresh blob, then
      // open the gate.
      ref
        ..invalidate(agentDbAvailabilityProvider)
        ..invalidate(agentResourceDbServiceProvider);
      state = const AiGateState.ready();
    } on Object catch (e) {
      state = AiGateState.downloadFailed(message: e.toString());
    } finally {
      _downloadInFlight = false;
    }
  }
}
