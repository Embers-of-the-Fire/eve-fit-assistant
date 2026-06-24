import "dart:async";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/feedback/feedback_dialog.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FeedbackGate extends ConsumerStatefulWidget {
  const FeedbackGate({required this.appRouter, required this.child, super.key});

  final AppRouter appRouter;
  final Widget child;

  @override
  ConsumerState<FeedbackGate> createState() => _FeedbackGateState();
}

class _FeedbackGateState extends ConsumerState<FeedbackGate> {
  bool _didCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didCheck) return;
    _didCheck = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkAndShowFeedback());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;

  Future<void> _checkAndShowFeedback() async {
    if (!_shouldShowFeedback()) return;

    final result = await showFeedbackDialog(context, navigatorKey: widget.appRouter.navigatorKey);
    if (!mounted) return;

    if (result.dontShowAgain) {
      FeedbackStateStore.dismiss();
      return;
    }

    switch (result.choice) {
      case FeedbackChoice.happy:
        FeedbackStateStore.markFeedbackGiven();
        unawaited(_showPositiveFollowUp());
      case FeedbackChoice.neutral:
      case FeedbackChoice.sad:
        FeedbackStateStore.markFeedbackGiven();
        unawaited(_showNegativeFollowUp());
      case null:
        FeedbackStateStore.remindLater();
    }
  }

  Future<void> _showPositiveFollowUp() async {
    await showPositiveFollowUpDialog(
      context,
      router: widget.appRouter,
      navigatorKey: widget.appRouter.navigatorKey,
    );
  }

  Future<void> _showNegativeFollowUp() async {
    await showNegativeFollowUpDialog(
      context,
      router: widget.appRouter,
      navigatorKey: widget.appRouter.navigatorKey,
    );
  }

  bool _shouldShowFeedback() {
    const minLaunchCount = 5;
    const minDaysSinceFirstLaunch = 2;
    const minDaysBetweenPrompts = 60;
    const maxRemindLaterCount = 3;
    const minMeaningfulActions = 1;

    final state = FeedbackStateStore.state;

    if (state.feedbackGiven) return false;
    if (state.launchCount < minLaunchCount) return false;
    if (state.firstLaunchDate == null) return false;
    if (DateTime.now().difference(state.firstLaunchDate!).inDays < minDaysSinceFirstLaunch) {
      return false;
    }
    if (state.remindedCount >= maxRemindLaterCount) return false;
    if (state.lastPromptDate != null &&
        DateTime.now().difference(state.lastPromptDate!).inDays < minDaysBetweenPrompts) {
      return false;
    }

    final meaningfulActions = _countMeaningfulActions();
    if (meaningfulActions < minMeaningfulActions) return false;

    return true;
  }

  int _countMeaningfulActions() {
    var count = 0;
    try {
      count += ref.read(fitRegistryManagerProvider).fits.length;
    } on Object catch (errorValue, stackTrace) {
      error("Failed to read fit registry for feedback gate: $errorValue", stackTrace: stackTrace);
    }
    try {
      final characters = ref.read(characterRegistryManagerProvider).characters;
      count += characters.values
          .where((m) => !CharacterRegistryManager.isBuiltInCharacterId(m.characterId))
          .length;
    } on Object catch (errorValue, stackTrace) {
      error(
        "Failed to read character registry for feedback gate: $errorValue",
        stackTrace: stackTrace,
      );
    }
    return count;
  }
}
