import "dart:async";

import "package:eve_fit_assistant/features/report/report_schema.dart";

/// The kind of manual feedback: an issue report about a specific document,
/// or a general question raised from the manual browser.
enum ManualFeedbackKind { report, question }

/// Payload for a manual feedback submission.
class ManualFeedback {
  const ManualFeedback({
    required this.kind,
    required this.title,
    required this.description,
    required this.contact,
    required this.locale,
    this.docId,
    this.docTitle,
  });

  final ManualFeedbackKind kind;
  final String title;
  final String description;
  final String contact;
  final String locale;

  /// Path-joined id of the document being reported, if any.
  final String? docId;

  /// Localized title of the document being reported, if any.
  final String? docTitle;
}

/// Submits manual feedback.
///
/// TODO(backend): the manual feedback endpoint is not implemented yet, so
/// this currently performs a dummy request that always succeeds. Wire it up
/// to the real backend (see `ReportApi`) once available.
class ManualFeedbackApi {
  Future<IssueResult> submit(ManualFeedback feedback) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    return const IssueResult(issueUrl: "", issueNumber: 0);
  }
}
