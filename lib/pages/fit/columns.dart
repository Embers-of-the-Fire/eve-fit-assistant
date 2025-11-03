part of "page.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({
    required this.fit,
    required this.fitMetadata,
    required this.fitWrapper,
    required this.ship,
    super.key,
  });

  final FitMetadata fitMetadata;
  final FitStorage fit;
  final FitWrapper fitWrapper;
  final Ship ship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          ...range(0, columns)
              .map<Widget>(
                (i) => Expanded(
                  child: _FitDisplayTab(
                    fitWrapper: fitWrapper,
                    initialIndex: i + 1,
                    ship: ship,
                    fitMetadata: fitMetadata,
                    fit: fit,
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
    required this.ship,
    required this.fitMetadata,
    required this.fitWrapper,
    required this.fit,
    this.initialIndex = 1,
  });

  final int initialIndex;

  final FitMetadata fitMetadata;
  final FitStorage fit;
  final FitWrapper fitWrapper;
  final Ship ship;

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
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(text: context.l10n.fitTabsCharacter),
          Tab(text: context.l10n.fitTabsEquipment),
          Tab(text: context.l10n.fitTabsAttributes),
          Tab(
            text: widget.ship.fighterTubes > 0
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
            _EquipmentTab(fit: widget.fit, fitWrapper: widget.fitWrapper, ship: widget.ship),
            _AttributeTab(fit: widget.fit),
            if (widget.ship.fighterTubes > 0)
              _FighterTab(fit: widget.fit)
            else
              _DroneTab(fit: widget.fit),
            ...const Column(children: [Center(child: Text("Tab content"))]).repeat(1),
          ],
        ),
      ),
    ],
  );
}
