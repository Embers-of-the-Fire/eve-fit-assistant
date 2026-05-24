part of "page.dart";

class BundleImpactWarningResult {
  const BundleImpactWarningResult({required this.continueAction, required this.dontShowAgain});

  final bool continueAction;
  final bool dontShowAgain;
}

Future<bool> confirmBundleImpactWarning(
  BuildContext context,
  WidgetRef ref,
  BundleImpactReport report,
) async {
  if (!ref.read(appSettingServiceProvider).showBundleImpactWarnings || !report.hasImpact) {
    return true;
  }

  final result = await showDialog<BundleImpactWarningResult>(
    context: context,
    builder: (dialogContext) => _BundleImpactWarningDialog(report: report),
  );
  if (!context.mounted || result == null || !result.continueAction) {
    return false;
  }

  if (result.dontShowAgain) {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.bundleImpactDisableConfirmTitle,
      content: Text(context.l10n.bundleImpactDisableConfirmDescription),
    );
    if (!context.mounted) {
      return false;
    }
    if (confirmed) {
      ref
          .read(appSettingServiceProvider.notifier)
          .update((setting) => setting.copyWith(showBundleImpactWarnings: false));
    }
  }

  return true;
}

@RoutePage()
class BundleImpactDetailPage extends ConsumerWidget {
  const BundleImpactDetailPage({required this.bundleId, this.report, super.key});

  final String bundleId;
  final BundleImpactReport? report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeReport = report;
    final BundleImpactReport detailReport =
        routeReport ?? ref.watch(bundleSwitchImpactProvider(bundleId));
    return Layout(
      title: context.l10n.bundleImpactDetailPageTitle,
      child: _BundleImpactDetailList(report: detailReport),
    );
  }
}

class _BundleImpactWarningDialog extends StatefulWidget {
  const _BundleImpactWarningDialog({required this.report});

  final BundleImpactReport report;

  @override
  State<_BundleImpactWarningDialog> createState() => _BundleImpactWarningDialogState();
}

class _BundleImpactWarningDialogState extends State<_BundleImpactWarningDialog> {
  bool _dontShowAgain = false;

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.bundleImpactWarningTitle,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_warningDescription(context, widget.report)),
          const SizedBox(height: 12),
          _BundleImpactSummaryList(report: widget.report),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _dontShowAgain,
            dense: true,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
            title: Text(context.l10n.dontShowAgain, style: context.theme.textTheme.bodyMedium),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => context.nav.pop(
          BundleImpactWarningResult(continueAction: false, dontShowAgain: _dontShowAgain),
        ),
        child: Text(context.l10n.cancel),
      ),
      OutlinedButton(
        onPressed: () {
          final bundleId = widget.report.target.targetBundle.bundleId;
          context.nav.pop(
            BundleImpactWarningResult(continueAction: false, dontShowAgain: _dontShowAgain),
          );
          unawaited(
            context.router.push(BundleImpactDetailRoute(bundleId: bundleId, report: widget.report)),
          );
        },
        child: Text(context.l10n.showDetails),
      ),
      ElevatedButton(
        onPressed: () => context.nav.pop(
          BundleImpactWarningResult(continueAction: true, dontShowAgain: _dontShowAgain),
        ),
        child: Text(context.l10n.bundleImpactContinueAction),
      ),
    ],
  );

  String _warningDescription(BuildContext context, BundleImpactReport report) =>
      switch (report.target.kind) {
        BundleImpactTargetKind.switchBundle => context.l10n.bundleImpactSwitchWarningDescription(
          bundleId: report.target.targetBundle.bundleId,
        ),
        BundleImpactTargetKind.incrementalImport =>
          context.l10n.bundleImpactIncrementalWarningDescription(
            bundleId: report.target.targetBundle.bundleId,
          ),
        BundleImpactTargetKind.fullReplacementImport =>
          context.l10n.bundleImpactIncrementalWarningDescription(
            bundleId: report.target.targetBundle.bundleId,
          ),
      };
}

class _BundleImpactSummaryList extends StatelessWidget {
  const _BundleImpactSummaryList({required this.report});

  final BundleImpactReport report;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (report.fits.isNotEmpty)
        _BundleImpactSummaryTile(
          icon: Icons.rocket_launch_outlined,
          label: context.l10n.bundleImpactFitsSummary(count: report.fits.length),
        ),
      if (report.characters.isNotEmpty)
        _BundleImpactSummaryTile(
          icon: Icons.person_outline,
          label: context.l10n.bundleImpactCharactersSummary(count: report.characters.length),
        ),
      if (report.bundleDataImpacted)
        _BundleImpactSummaryTile(
          icon: Icons.inventory_2_outlined,
          label: context.l10n.bundleImpactBundleDataSummary,
        ),
    ],
  );
}

class _BundleImpactSummaryTile extends StatelessWidget {
  const _BundleImpactSummaryTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(leading: Icon(icon), title: Text(label)),
  );
}

class _BundleImpactDetailList extends StatelessWidget {
  const _BundleImpactDetailList({required this.report});

  final BundleImpactReport report;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(
        context.l10n.bundleImpactDetailDescription(bundleId: report.target.targetBundle.bundleId),
        style: context.theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      if (!report.hasImpact) Text(context.l10n.bundleImpactNoImpacts),
      if (report.fits.isNotEmpty) ...[
        _BundleImpactSectionTitle(title: context.l10n.bundleImpactFitsSection),
        for (final fit in report.fits)
          _BundleImpactDetailTile(
            title: fit.metadata.name,
            subtitle: fit.metadata.fitId,
            reason: fit.reason,
            savedBundleId: fit.metadata.bundleSnapshot.bundleId,
            targetBundleId: report.target.targetBundle.bundleId,
          ),
      ],
      if (report.characters.isNotEmpty) ...[
        _BundleImpactSectionTitle(title: context.l10n.bundleImpactCharactersSection),
        for (final character in report.characters)
          _BundleImpactDetailTile(
            title: character.metadata.name,
            subtitle: character.metadata.characterId,
            reason: character.reason,
            savedBundleId: character.metadata.bundleSnapshot.bundleId,
            targetBundleId: report.target.targetBundle.bundleId,
          ),
      ],
      if (report.bundleDataImpacted) ...[
        _BundleImpactSectionTitle(title: context.l10n.bundleImpactBundleDataSection),
        _BundleImpactDetailTile(
          title: context.l10n.bundleImpactBundleDataSummary,
          subtitle: report.target.targetBundle.bundleId,
          reason: report.target.kind == BundleImpactTargetKind.fullReplacementImport
              ? BundleImpactReason.fullReplacement
              : BundleImpactReason.incrementalPatch,
          savedBundleId:
              report.target.sourceBundle?.bundleId ?? report.target.targetBundle.bundleId,
          targetBundleId: report.target.targetBundle.bundleId,
        ),
      ],
    ],
  );
}

class _BundleImpactSectionTitle extends StatelessWidget {
  const _BundleImpactSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(title, style: context.theme.textTheme.titleMedium),
  );
}

class _BundleImpactDetailTile extends StatelessWidget {
  const _BundleImpactDetailTile({
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.savedBundleId,
    required this.targetBundleId,
  });

  final String title;
  final String subtitle;
  final BundleImpactReason reason;
  final String savedBundleId;
  final String targetBundleId;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text(title),
      subtitle: Text(
        "$subtitle\n"
        "${context.l10n.bundleImpactSavedBundleLabel}$savedBundleId\n"
        "${context.l10n.bundleImpactTargetBundleLabel}$targetBundleId\n"
        "${context.l10n.bundleImpactReasonLabel}${_localizeReason(context, reason)}",
      ),
      isThreeLine: true,
    ),
  );

  String _localizeReason(BuildContext context, BundleImpactReason reason) => switch (reason) {
    BundleImpactReason.bundleIdMismatch => context.l10n.bundleImpactReasonBundleMismatch,
    BundleImpactReason.missingComparableRevision => context.l10n.bundleImpactReasonMissingRevision,
    BundleImpactReason.manifestMismatch => context.l10n.bundleImpactReasonManifestMismatch,
    BundleImpactReason.generationMismatch => context.l10n.bundleImpactReasonGenerationMismatch,
    BundleImpactReason.buildMismatch => context.l10n.bundleImpactReasonBuildMismatch,
    BundleImpactReason.appVersionMismatch => context.l10n.bundleImpactReasonAppVersionMismatch,
    BundleImpactReason.incrementalPatch => context.l10n.bundleImpactReasonIncrementalPatch,
    BundleImpactReason.fullReplacement => context.l10n.bundleImpactReasonFullReplacement,
  };
}
