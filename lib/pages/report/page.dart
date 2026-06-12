import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/report/report_api.dart";
import "package:eve_fit_assistant/features/report/report_schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

@RoutePage()
class ReportFeedbackPage extends ConsumerStatefulWidget {
  const ReportFeedbackPage({super.key});

  @override
  ConsumerState<ReportFeedbackPage> createState() => _ReportFeedbackPageState();
}

class _ReportFeedbackPageState extends ConsumerState<ReportFeedbackPage>
    with TickerProviderStateMixin {
  static const _githubIssuesUrl = "https://github.com/Embers-of-the-Fire/eve-fit-assistant/issues";
  static const _tencentFormUrl = "https://docs.qq.com/form/page/DV0JsUURRU054Y3pY";

  late final TabController _tabController;

  final _bugFormKey = GlobalKey<FormState>();
  final _featureFormKey = GlobalKey<FormState>();

  final _bugTitleCtrl = TextEditingController();
  final _bugSummaryCtrl = TextEditingController();
  final _bugStepsCtrl = TextEditingController();
  final _bugExpectedCtrl = TextEditingController();
  final _bugActualCtrl = TextEditingController();
  final _bugVersionCtrl = TextEditingController();
  final _bugLogsCtrl = TextEditingController();

  final _featureTitleCtrl = TextEditingController();
  final _featureProblemCtrl = TextEditingController();
  final _featureProposalCtrl = TextEditingController();
  final _featureImpactCtrl = TextEditingController();
  final _featureAlternativesCtrl = TextEditingController();
  final _featureExtraCtrl = TextEditingController();

  final _contactCtrl = TextEditingController();

  ReportPlatform _bugPlatform = ReportPlatform.android;
  bool _submitting = false;

  final _api = ReportApi();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bugTitleCtrl.dispose();
    _bugSummaryCtrl.dispose();
    _bugStepsCtrl.dispose();
    _bugExpectedCtrl.dispose();
    _bugActualCtrl.dispose();
    _bugVersionCtrl.dispose();
    _bugLogsCtrl.dispose();
    _featureTitleCtrl.dispose();
    _featureProblemCtrl.dispose();
    _featureProposalCtrl.dispose();
    _featureImpactCtrl.dispose();
    _featureAlternativesCtrl.dispose();
    _featureExtraCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_submitting,
    child: DefaultTabController(
      length: 2,
      child: Layout(
        title: context.l10n.reportPageTitle,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.reportTabBug),
            Tab(text: context.l10n.reportTabFeature),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildBugForm(), _buildFeatureForm()],
              ),
            ),
            _buildSubmitButton(),
          ],
        ),
      ),
    ),
  );

  Widget _buildBugForm() => Form(
    key: _bugFormKey,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildField(
          context.l10n.reportFieldTitle,
          _bugTitleCtrl,
          1,
          hint: context.l10n.reportFieldTitleHint,
          required: context.l10n.reportFieldTitleRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldSummary,
          _bugSummaryCtrl,
          1,
          hint: context.l10n.reportFieldSummaryHint,
          required: context.l10n.reportFieldSummaryRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldSteps,
          _bugStepsCtrl,
          3,
          hint: context.l10n.reportFieldStepsHint,
          required: context.l10n.reportFieldStepsRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldExpected,
          _bugExpectedCtrl,
          3,
          hint: context.l10n.reportFieldExpectedHint,
          required: context.l10n.reportFieldExpectedRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldActual,
          _bugActualCtrl,
          3,
          hint: context.l10n.reportFieldActualHint,
          required: context.l10n.reportFieldActualRequired,
        ),
        const SizedBox(height: 16),
        _buildPlatformDropdown(),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldVersion,
          _bugVersionCtrl,
          1,
          hint: context.l10n.reportFieldVersionHint,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldLogs,
          _bugLogsCtrl,
          4,
          hint: context.l10n.reportFieldLogsHint,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldContact,
          _contactCtrl,
          1,
          hint: context.l10n.reportFieldContactHint,
        ),
        const SizedBox(height: 32),
      ],
    ),
  );

  Widget _buildFeatureForm() => Form(
    key: _featureFormKey,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildField(
          context.l10n.reportFieldTitle,
          _featureTitleCtrl,
          1,
          hint: context.l10n.reportFieldTitleHint,
          required: context.l10n.reportFieldTitleRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldProblem,
          _featureProblemCtrl,
          3,
          hint: context.l10n.reportFieldProblemHint,
          required: context.l10n.reportFieldProblemRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldProposal,
          _featureProposalCtrl,
          3,
          hint: context.l10n.reportFieldProposalHint,
          required: context.l10n.reportFieldProposalRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldImpact,
          _featureImpactCtrl,
          3,
          hint: context.l10n.reportFieldImpactHint,
          required: context.l10n.reportFieldImpactRequired,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldAlternatives,
          _featureAlternativesCtrl,
          3,
          hint: context.l10n.reportFieldAlternativesHint,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldExtra,
          _featureExtraCtrl,
          3,
          hint: context.l10n.reportFieldExtraHint,
        ),
        const SizedBox(height: 16),
        _buildField(
          context.l10n.reportFieldContact,
          _contactCtrl,
          1,
          hint: context.l10n.reportFieldContactHint,
        ),
        const SizedBox(height: 32),
      ],
    ),
  );

  Widget _buildPlatformDropdown() => DropdownButtonFormField<ReportPlatform>(
    value: _bugPlatform,
    decoration: InputDecoration(
      labelText: context.l10n.reportFieldPlatform,
      border: const OutlineInputBorder(),
    ),
    items: ReportPlatform.values
        .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
        .toList(),
    onChanged: (v) {
      if (v != null) setState(() => _bugPlatform = v);
    },
    validator: (_) => context.l10n.reportFieldPlatformRequired,
  );

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    int maxLines, {
    String? hint,
    String? required,
  }) => TextFormField(
    controller: ctrl,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    ),
    validator: (value) {
      if (required != null && (value == null || value.trim().isEmpty)) {
        return required;
      }
      return null;
    },
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
              : Text(context.l10n.reportSubmit),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    final isBug = _tabController.index == 0;
    final formKey = isBug ? _bugFormKey : _featureFormKey;
    if (!formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final locale = Localizations.localeOf(context).languageCode;
      final language = locale.startsWith("zh") ? "zh" : "en";

      final IssueResult result;
      if (isBug) {
        result = await _api.submitBugReport(
          BugReport(
            title: _bugTitleCtrl.text.trim(),
            summary: _bugSummaryCtrl.text.trim(),
            steps: _bugStepsCtrl.text.trim(),
            expected: _bugExpectedCtrl.text.trim(),
            actual: _bugActualCtrl.text.trim(),
            platform: _bugPlatform,
            version: _bugVersionCtrl.text.trim(),
            logs: _bugLogsCtrl.text.trim(),
            contact: _contactCtrl.text.trim(),
          ),
          language,
        );
      } else {
        result = await _api.submitFeatureRequest(
          FeatureRequest(
            title: _featureTitleCtrl.text.trim(),
            problem: _featureProblemCtrl.text.trim(),
            proposal: _featureProposalCtrl.text.trim(),
            impact: _featureImpactCtrl.text.trim(),
            alternatives: _featureAlternativesCtrl.text.trim(),
            extra: _featureExtraCtrl.text.trim(),
            contact: _contactCtrl.text.trim(),
          ),
          language,
        );
      }

      if (!mounted) return;
      _clearForms();
      setState(() => _submitting = false);
      _showSuccessDialog(result);
    } on ReportApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showErrorDialog(e.message);
    }
  }

  void _clearForms() {
    _bugTitleCtrl.clear();
    _bugSummaryCtrl.clear();
    _bugStepsCtrl.clear();
    _bugExpectedCtrl.clear();
    _bugActualCtrl.clear();
    _bugVersionCtrl.clear();
    _bugLogsCtrl.clear();
    _featureTitleCtrl.clear();
    _featureProblemCtrl.clear();
    _featureProposalCtrl.clear();
    _featureImpactCtrl.clear();
    _featureAlternativesCtrl.clear();
    _featureExtraCtrl.clear();
    _contactCtrl.clear();
    setState(() => _bugPlatform = ReportPlatform.android);
  }

  void _showSuccessDialog(IssueResult result) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (ctx) => AppDialog(
          title: context.l10n.reportSuccessTitle,
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.reportSuccessBody(issueUrl: result.issueUrl)),
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
                const SizedBox(height: 16),
                Text(context.l10n.reportErrorExternalHint),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(context.l10n.reportTileGitHub),
                  subtitle: Text(context.l10n.reportTileGitHubDescription),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    ctx.nav.pop();
                    unawaited(_openUrl(Uri.parse(_githubIssuesUrl)));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(context.l10n.reportTileTencentForm),
                  subtitle: Text(context.l10n.reportTileTencentFormDescription),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    ctx.nav.pop();
                    unawaited(_openUrl(Uri.parse(_tencentFormUrl)));
                  },
                ),
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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.reportOpenError)));
      }
    }
  }
}

extension on ReportPlatform {
  String get label => switch (this) {
    ReportPlatform.android => "Android",
    ReportPlatform.ios => "iOS",
    ReportPlatform.windows => "Windows 10/11",
    ReportPlatform.linux => "Linux",
    ReportPlatform.other => "Other",
  };
}
