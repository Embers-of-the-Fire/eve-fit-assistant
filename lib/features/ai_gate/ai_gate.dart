import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_controller.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_state.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Gates an AI-assistant surface behind the disclaimer acknowledgement, the
/// global enable flag, and agent database availability.
///
/// Renders [child] only in the ready state; every other state is a full-body
/// notice page (never a dialog) with the appropriate action. The surrounding
/// page is expected to provide the scaffold/app bar.
class AiFeatureGate extends ConsumerWidget {
  const AiFeatureGate({required this.child, super.key});

  /// The AI feature content shown once the gate is fully open.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (ref.watch(
    aiGateControllerProvider,
  )) {
    AiGateReady() => child,
    AiGateDisclaimer() => const _DisclaimerView(),
    AiGateEnable() => const _EnableView(),
    AiGateLoading() => const Center(child: CircularProgressIndicator()),
    AiGateDownloading(:final downloadedBytes, :final totalBytes) => _DownloadingView(
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
    ),
    AiGateDownloadFailed(:final message) => _DownloadFailedView(message: message),
    AiGateDataRequiredNoCheckout() => const _DataRequiredView(
      description: _DataRequiredKind.noCheckout,
    ),
    AiGateDataRequiredUpdate() => const _DataRequiredView(description: _DataRequiredKind.update),
    AiGateDataRequiredDownload() => const _DataRequiredView(
      description: _DataRequiredKind.download,
    ),
  };
}

class _NoticeView extends StatelessWidget {
  const _NoticeView({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const .all(24),
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 16),
          Text(title, style: context.theme.textTheme.titleMedium, textAlign: .center),
          const SizedBox(height: 8),
          Text(description, style: context.theme.textTheme.bodyMedium, textAlign: .center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class _DisclaimerView extends ConsumerWidget {
  const _DisclaimerView();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _NoticeView(
    icon: Icons.smart_toy_outlined,
    title: context.l10n.aiDisclaimerTitle,
    description: context.l10n.aiDisclaimerDescription,
    action: ElevatedButton(
      onPressed: () => ref.read(aiGateControllerProvider.notifier).acknowledgeDisclaimer(),
      child: Text(context.l10n.aiDisclaimerAcknowledge),
    ),
  );
}

class _EnableView extends ConsumerWidget {
  const _EnableView();

  @override
  Widget build(BuildContext context, WidgetRef ref) => _NoticeView(
    icon: Icons.power_settings_new,
    title: context.l10n.aiEnableTitle,
    description: context.l10n.aiEnableDescription,
    action: ElevatedButton(
      onPressed: () => unawaited(ref.read(aiGateControllerProvider.notifier).enableAssistant()),
      child: Text(context.l10n.aiEnableButton),
    ),
  );
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.downloadedBytes, required this.totalBytes});

  final int downloadedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final fraction = totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : null;
    return Center(
      child: Padding(
        padding: const .all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Text(
              context.l10n.aiDownloadingTitle,
              style: context.theme.textTheme.titleMedium,
              textAlign: .center,
            ),
            const SizedBox(height: 16),
            SizedBox(width: 280, child: LinearProgressIndicator(value: fraction)),
            if (fraction != null) ...[
              const SizedBox(height: 8),
              Text(
                "${(fraction * 100).toStringAsFixed(0)}%",
                style: context.theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DownloadFailedView extends ConsumerWidget {
  const _DownloadFailedView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _NoticeView(
    icon: Icons.error_outline,
    title: context.l10n.aiDownloadFailedTitle,
    description: message,
    action: ElevatedButton(
      onPressed: () => unawaited(ref.read(aiGateControllerProvider.notifier).downloadAgentDb()),
      child: Text(context.l10n.retry),
    ),
  );
}

enum _DataRequiredKind { noCheckout, update, download }

class _DataRequiredView extends ConsumerWidget {
  const _DataRequiredView({required this.description});

  final _DataRequiredKind description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final (text, action) = switch (description) {
      _DataRequiredKind.noCheckout => (
        l10n.aiDataRequiredNoCheckoutDescription,
        ElevatedButton(
          onPressed: () => unawaited(context.router.push(const StorageManagement())),
          child: Text(l10n.aiManageDataButton),
        ),
      ),
      _DataRequiredKind.update => (
        l10n.aiDataRequiredUpdateDescription,
        ElevatedButton(
          onPressed: () => unawaited(context.router.push(const StorageManagement())),
          child: Text(l10n.aiManageDataButton),
        ),
      ),
      _DataRequiredKind.download => (
        l10n.aiDataRequiredDownloadDescription,
        ElevatedButton(
          onPressed: () => unawaited(ref.read(aiGateControllerProvider.notifier).downloadAgentDb()),
          child: Text(l10n.aiDownloadDataButton),
        ),
      ),
    };
    return _NoticeView(
      icon: Icons.cloud_download_outlined,
      title: l10n.aiDataRequiredTitle,
      description: text,
      action: action,
    );
  }
}
