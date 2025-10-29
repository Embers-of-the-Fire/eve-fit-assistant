import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FitDisplayColumns extends ConsumerWidget {
  const FitDisplayColumns({
    required this.fit,
    required this.fitMetadata,
    required this.ship,
    super.key,
  });

  final FitMetadata fitMetadata;
  final FitStorage fit;
  final Ship ship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);

    return Row(
      children: [
        ...range(0, columns)
            .map<Widget>(
              (i) => Expanded(
                child: _FitDisplayTab(
                  initialIndex: i + 1,
                  ship: ship,
                  fitMetadata: fitMetadata,
                  fit: fit,
                ),
              ),
            )
            .intersperse(const VerticalDivider(indent: 8, endIndent: 8)),
      ],
    );
  }
}

class FitDisplayColumn extends StatelessWidget {
  const FitDisplayColumn({
    required this.fit,
    required this.fitMetadata,
    required this.ship,
    super.key,
  });

  final FitMetadata fitMetadata;
  final FitStorage fit;
  final Ship ship;

  @override
  Widget build(BuildContext context) =>
      Center(child: Column(children: [Text("$fitMetadata\n"), Text("$fit\n")]));
}

class _FitDisplayTab extends StatefulWidget {
  const _FitDisplayTab({
    required this.ship,
    required this.fitMetadata,
    required this.fit,
    // Maybe false positive: unused parameter
    // ignore: unused_element_parameter
    this.initialIndex = 1,
  });

  final int initialIndex;

  final FitMetadata fitMetadata;
  final FitStorage fit;
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
            text: widget.fit.body.fighters.isNotEmpty
                ? context.l10n.fitTabsFighter
                : context.l10n.fitTabsDrone,
          ),
          Tab(text: context.l10n.fitTabsUtils),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: const Column(children: [Center(child: Text("Tab content"))]).repeat(5).toList(),
        ),
      ),
    ],
  );
}
