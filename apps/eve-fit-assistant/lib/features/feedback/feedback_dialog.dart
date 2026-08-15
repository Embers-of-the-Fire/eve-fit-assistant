import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

enum FeedbackChoice { happy, neutral, sad }

class FeedbackDialogResult {
  const FeedbackDialogResult({required this.choice, required this.dontShowAgain});

  final FeedbackChoice? choice;
  final bool dontShowAgain;
}

Future<FeedbackDialogResult> showFeedbackDialog(
  BuildContext context, {
  GlobalKey<NavigatorState>? navigatorKey,
}) => showDialog<FeedbackDialogResult>(
  context: navigatorKey?.currentContext ?? context,
  barrierDismissible: false,
  builder: (context) => const _FeedbackDialog(),
).then((r) => r ?? const FeedbackDialogResult(choice: null, dontShowAgain: false));

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  bool _dontShowAgain = false;

  void _onSelect(FeedbackChoice choice) {
    context.nav.pop(FeedbackDialogResult(choice: choice, dontShowAgain: _dontShowAgain));
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: "How is your experience so far?",
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Your feedback helps make Eve Fit Assistant better.",
            style: context.theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _EmojiButton(
                emoji: "😊",
                label: "Love it",
                onTap: () => _onSelect(FeedbackChoice.happy),
              ),
              _EmojiButton(
                emoji: "😐",
                label: "It's OK",
                onTap: () => _onSelect(FeedbackChoice.neutral),
              ),
              _EmojiButton(
                emoji: "☹️",
                label: "Not great",
                onTap: () => _onSelect(FeedbackChoice.sad),
              ),
            ],
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _dontShowAgain,
            dense: true,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
            title: Text("Don't ask again", style: context.theme.textTheme.bodyMedium),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () =>
            context.nav.pop(const FeedbackDialogResult(choice: null, dontShowAgain: false)),
        child: const Text("Remind later"),
      ),
    ],
  );
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(label, style: context.theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

Future<void> showPositiveFollowUpDialog(
  BuildContext context, {
  required StackRouter router,
  GlobalKey<NavigatorState>? navigatorKey,
}) => showDialog<void>(
  context: navigatorKey?.currentContext ?? context,
  builder: (ctx) => AppDialog(
    title: "Any feedback?",
    content: Text(
      "We are glad you are enjoying the app! "
      "If you have any ideas or suggestions, we would love to hear them.",
      style: Theme.of(ctx).textTheme.bodyMedium,
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          unawaited(router.push(ReportFeedbackRoute(initialTab: 1)));
        },
        child: const Text("Request a feature"),
      ),
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Close")),
    ],
  ),
);

Future<void> showNegativeFollowUpDialog(
  BuildContext context, {
  required StackRouter router,
  GlobalKey<NavigatorState>? navigatorKey,
}) => showDialog<void>(
  context: navigatorKey?.currentContext ?? context,
  builder: (ctx) => AppDialog(
    title: "Experienced a bug or missing a feature?",
    content: Text(
      "We are sorry things are not going smoothly. "
      "Help us improve — let us know what went wrong or what you need.",
      style: Theme.of(ctx).textTheme.bodyMedium,
    ),
    actions: [
      TextButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          unawaited(router.push(ReportFeedbackRoute()));
        },
        child: const Text("Report a bug"),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(ctx).pop();
          unawaited(router.push(ReportFeedbackRoute(initialTab: 1)));
        },
        child: const Text("Request a feature"),
      ),
      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Close")),
    ],
  ),
);
