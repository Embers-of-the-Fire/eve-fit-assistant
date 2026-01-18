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
                  child: _FitDisplayTab(fitContext: fitContext, initialIndex: i + 1),
                ),
              )
              .intersperse(const VerticalDivider(indent: 8, endIndent: 8)),
        ],
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(initialIndex: widget.initialIndex, length: 5, vsync: this);
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
            ...const Column(children: [Center(child: Text("Tab content"))]).repeat(1),
            _EquipmentTab(fitContext: widget.fitContext),
            _AttributeTab(fitContext: widget.fitContext),
            if (widget.fitContext.ship.fighterTubes > 0)
              _FighterTab(fit: widget.fitContext.fit)
            else
              _DroneTab(fit: widget.fitContext.fit),
            ...const Column(children: [Center(child: Text("Tab content"))]).repeat(1),
          ],
        ),
      ),
    ],
  );
}
