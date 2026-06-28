import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/feedback/feedback_dialog.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class TriggerFeedbackTile extends ConsumerWidget {
  const TriggerFeedbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.feedback_outlined),
    title: const Text("Trigger Feedback Dialog"),
    subtitle: const Text("Reset state and show the feedback prompt immediately"),
    onTap: () => _confirm(context, ref),
  );

  void _confirm(BuildContext context, WidgetRef ref) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text("Trigger Feedback Dialog?"),
          content: const Text(
            "This will reset the feedback state and show the feedback dialog immediately.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogCtx).pop(), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogCtx).pop();
                unawaited(_trigger(context));
              },
              child: const Text("Trigger"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _trigger(BuildContext context) async {
    final router = context.router;
    FeedbackStateStore.resetForTesting();
    final result = await showFeedbackDialog(context);
    if (!context.mounted) return;
    if (result.dontShowAgain) {
      FeedbackStateStore.dismiss();
      return;
    }
    switch (result.choice) {
      case FeedbackChoice.happy:
        FeedbackStateStore.markFeedbackGiven();
        unawaited(showPositiveFollowUpDialog(context, router: router));
      case FeedbackChoice.neutral:
      case FeedbackChoice.sad:
        FeedbackStateStore.markFeedbackGiven();
        unawaited(showNegativeFollowUpDialog(context, router: router));
      case null:
        FeedbackStateStore.remindLater();
    }
  }
}
