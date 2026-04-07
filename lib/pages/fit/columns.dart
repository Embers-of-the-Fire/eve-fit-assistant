part of "page.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);
    final fitState = ref.watch(fitProvider(fitContext.fitId));
    final emulatorState = ref.watch(fitEmulatorServiceProvider(fitContext.fitId));
    final status = fitState.status;
    final saveErrorMessage = status.maybeWhen(error: (message) => message, orElse: () => null);

    return Padding(
      padding: const .symmetric(horizontal: 6),
      child: Column(
        children: [
          if (saveErrorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FitStatusBanner(
                icon: Icons.save_as_outlined,
                title: context.l10n.fitPageSaveErrorTitle,
                message: saveErrorMessage,
              ),
            ),
          if (emulatorState.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _FitStatusBanner(
                icon: Icons.calculate_outlined,
                title: context.l10n.fitPageStatsUnavailableTitle,
                message: emulatorState.errorMessage ?? context.l10n.fitPageStatsUnavailableMessage,
                action: FilledButton.tonalIcon(
                  onPressed: ref.read(fitEmulatorServiceProvider(fitContext.fitId).notifier).retry,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.fitPageRetryAction),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FitSkillPolicyBanner(fitContext: fitContext),
          ),
          Expanded(
            child: Row(
              children: [
                ...range(0, columns)
                    .map<Widget>(
                      (i) => Expanded(
                        child: _FitDisplayTab(fitContext: fitContext, initialIndex: i + 1),
                      ),
                    )
                    .intersperse(const VerticalDivider(indent: 8, endIndent: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FitStatusBanner extends StatelessWidget {
  const _FitStatusBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(message),
        trailing: action,
      ),
    );
  }
}

extension on FitSkillProfile {
  String localizedName(BuildContext context) => switch (this) {
    FitSkillProfile.all5 => context.l10n.fitSkillProfileAll5,
    FitSkillProfile.all0 => context.l10n.fitSkillProfileAll0,
  };
}

class _FitSkillPolicyBanner extends StatelessWidget {
  const _FitSkillPolicyBanner({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final skillProfile = fitContext.fit.body.skillProfile;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.fitSkillPolicyPresetTitle(
                      profileName: skillProfile.localizedName(context),
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.l10n.fitSkillPolicyPresetDescription),
            const SizedBox(height: 12),
            SegmentedButton<FitSkillProfile>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<FitSkillProfile>(
                  value: FitSkillProfile.all5,
                  label: Text(FitSkillProfile.all5.localizedName(context)),
                ),
                ButtonSegment<FitSkillProfile>(
                  value: FitSkillProfile.all0,
                  label: Text(FitSkillProfile.all0.localizedName(context)),
                ),
              ],
              selected: {skillProfile},
              onSelectionChanged: (selection) async {
                final nextProfile = selection.firstOrNull;
                if (nextProfile == null || nextProfile == skillProfile) {
                  return;
                }
                await fitContext.fitWrapper.setSkillProfile(nextProfile);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FitDisplayTab extends StatefulWidget {
  const _FitDisplayTab({required this.fitContext, this.initialIndex = 1});

  final int initialIndex;

  final FitContext fitContext;

  @override
  State<_FitDisplayTab> createState() => _FitDisplayTabState();
}

class _FitDisplayTabState extends State<_FitDisplayTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final FitInteractionOptions _interactionOptions;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(initialIndex: widget.initialIndex, length: 5, vsync: this);
    _interactionOptions = const FitInteractionOptions();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabController,
        labelPadding: .zero,
        tabs: [
          Tab(text: context.l10n.fitTabsCharacter),
          Tab(text: context.l10n.fitTabsEquipment),
          Tab(text: context.l10n.fitTabsAttributes),
          Tab(
            text: widget.fitContext.ship.fighterTubes > 0
                ? context.l10n.fitTabsFighter
                : context.l10n.fitTabsDrone,
          ),
          Tab(text: context.l10n.fitTabsUtils),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _CharacterTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions),
            _EquipmentTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions),
            _AttributeTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions),
            if (widget.fitContext.ship.fighterTubes > 0)
              _FighterTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions)
            else
              _DroneTab(fitContext: widget.fitContext, interactionOptions: _interactionOptions),
            _UtilsTab(fitContext: widget.fitContext),
          ],
        ),
      ),
    ],
  );
}
