part of "page.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);

    return Padding(
      padding: const .symmetric(horizontal: 6),
      child: Column(
        children: [
          if (!currentFitSkillPolicy.supportsSkillAwareSimulation)
            const Padding(padding: .only(bottom: 8), child: _FitSkillPolicyBanner()),
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

class _FitSkillPolicyBanner extends StatelessWidget {
  const _FitSkillPolicyBanner();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        leading: Icon(Icons.info_outline, color: colorScheme.primary),
        title: Text(context.l10n.fitSkillPolicyUnsupportedTitle),
        subtitle: Text(context.l10n.fitSkillPolicyUnsupportedDescription),
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
