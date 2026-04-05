part of "page.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);

    return Padding(
      padding: const .symmetric(horizontal: 6),
      child: Row(
        children: [
          ...range(0, columns)
              .map<Widget>(
                (i) => Expanded(
                  child: _FitDisplayTab(
                    fitContext: fitContext,
                    initialIndex: i + 1,
                    showQuickActions: i == 0,
                  ),
                ),
              )
              .intersperse(const VerticalDivider(indent: 8, endIndent: 8)),
        ],
      ),
    );
  }
}

class _FitDisplayTab extends StatefulWidget {
  const _FitDisplayTab({
    required this.fitContext,
    this.initialIndex = 1,
    this.showQuickActions = false,
  });

  final int initialIndex;

  final FitContext fitContext;
  final bool showQuickActions;

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
      if (widget.showQuickActions) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: _FitQuickActions(fitContext: widget.fitContext),
        ),
        const Divider(height: 1),
      ],
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

class _FitQuickActions extends StatelessWidget {
  const _FitQuickActions({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      OutlinedButton.icon(
        onPressed: () =>
            showFitExportDialog(context, fitId: fitContext.fitId, initialFit: fitContext.fit),
        icon: const Icon(Icons.ios_share_outlined),
        label: Text(context.l10n.fitUtilsExportButton),
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (context) => FitScreenshotPage(fitId: fitContext.fitId)),
        ),
        icon: const Icon(Icons.image_outlined),
        label: Text(context.l10n.fitUtilsExportImageButton),
      ),
    ],
  );
}
