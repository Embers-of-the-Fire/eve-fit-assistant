import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/manual/repository/manual_feedback_api.dart";
import "package:eve_fit_assistant/features/report/report_api.dart";
import "package:eve_fit_assistant/features/report/report_schema.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

@RoutePage()
class ManualFeedbackPage extends ConsumerStatefulWidget {
  const ManualFeedbackPage({required this.kind, super.key, this.docId, this.docTitle});

  final ManualFeedbackKind kind;

  /// Path-joined id of the document being reported (e.g. `fitting/modules`);
  /// only set when [kind] is [ManualFeedbackKind.report].
  final String? docId;

  /// Localized title of the document being reported; used to prefill the
  /// title field.
  final String? docTitle;

  @override
  ConsumerState<ManualFeedbackPage> createState() => _ManualFeedbackPageState();
}

class _ManualFeedbackPageState extends ConsumerState<ManualFeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  final _descriptionCtrl = TextEditingController();

  bool _submitting = false;
  bool _includeMetadata = true;

  final _api = ManualFeedbackApi();

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.docTitle ?? "");
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: Layout(
      title: switch (widget.kind) {
        ManualFeedbackKind.report => context.l10n.manualReportPageTitle,
        ManualFeedbackKind.question => context.l10n.manualQuestionPageTitle,
      },
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.kind == ManualFeedbackKind.report && widget.docId != null) ...[
                    _buildReportedPageCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildCard([
                    _buildField(
                      context.l10n.reportFieldTitle,
                      _titleCtrl,
                      hint: context.l10n.reportFieldTitleHint,
                      required: context.l10n.reportFieldTitleRequired,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      context.l10n.manualFeedbackFieldDescription,
                      _descriptionCtrl,
                      minLines: 4,
                      hint: context.l10n.manualFeedbackFieldDescriptionHint,
                      required: context.l10n.manualFeedbackFieldDescriptionRequired,
                    ),
                    const SizedBox(height: 16),
                    _buildMetadataToggle(),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    ),
  );

  Widget _buildReportedPageCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          context.l10n.manualFeedbackReportedPage,
          style: context.theme.textTheme.labelLarge?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(widget.docTitle ?? widget.docId!),
          subtitle: Text("/manual/${widget.docId}"),
        ),
      ),
    ],
  );

  Widget _buildCard(List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    int minLines = 1,
    String? hint,
    String? helperText,
    String? required,
  }) {
    final effectiveMaxLines = minLines;
    return TextFormField(
      controller: ctrl,
      minLines: minLines,
      maxLines: effectiveMaxLines == 1 ? 1 : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (required != null && (value == null || value.trim().isEmpty)) {
          return required;
        }
        return null;
      },
    );
  }

  Widget _buildMetadataToggle() => CheckboxListTile(
    value: _includeMetadata,
    title: Text(context.l10n.reportFieldIncludeMetadata),
    subtitle: Text(context.l10n.reportFieldIncludeMetadataHint),
    controlAffinity: ListTileControlAffinity.leading,
    contentPadding: EdgeInsets.zero,
    onChanged: _submitting ? null : (v) => setState(() => _includeMetadata = v ?? true),
  );

  Widget _buildSubmitButton() => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                )
              : Text(switch (widget.kind) {
                  ManualFeedbackKind.report => context.l10n.reportSubmit,
                  ManualFeedbackKind.question => context.l10n.questionSubmit,
                }),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final includeMetadata = _includeMetadata;
    setState(() => _submitting = true);

    try {
      final locale = Localizations.localeOf(context).languageCode;
      final result = await _api.submit(
        ManualFeedback(
          kind: widget.kind,
          title: _titleCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
          locale: locale.startsWith("zh") ? "zh" : "en",
          docId: widget.docId,
        ),
        includeMetadata: includeMetadata,
      );

      if (!mounted) return;
      _clearForm();
      setState(() => _submitting = false);
      _showSuccessDialog(result);
    } on ReportApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorDialog(e.message);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorDialog("An unexpected error occurred: $e");
    }
  }

  void _clearForm() {
    _titleCtrl.clear();
    _descriptionCtrl.clear();
    setState(() => _includeMetadata = true);
  }

  void _showSuccessDialog(IssueResult result) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: switch (widget.kind) {
            ManualFeedbackKind.report => context.l10n.reportSuccessTitle,
            ManualFeedbackKind.question => context.l10n.questionSuccessTitle,
          },
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (widget.kind) {
                  ManualFeedbackKind.report => context.l10n.reportSuccessBody(
                    issueUrl: result.issueUrl,
                  ),
                  ManualFeedbackKind.question => context.l10n.questionSuccessBody(
                    issueUrl: result.issueUrl,
                  ),
                }),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(context.l10n.reportViewIssue),
                    onPressed: () => _openUrl(Uri.parse(result.issueUrl)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => ctx.nav.pop(),
              child: Text(context.l10n.reportDialogClose),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: context.l10n.reportErrorServer,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.reportErrorNetwork),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(message, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => ctx.nav.pop(), child: Text(context.l10n.reportDialogClose)),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(Uri uri) async {
    try {
      final didLaunch = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!didLaunch && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
      }
    }
  }
}

/// App-bar action that opens the manual question page.
class ManualQuestionAction extends StatelessWidget {
  const ManualQuestionAction({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.help_outline),
    tooltip: context.l10n.manualActionQuestionTooltip,
    onPressed: () =>
        unawaited(context.router.push(ManualFeedbackRoute(kind: ManualFeedbackKind.question))),
  );
}
