import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/market_price/state/state.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/num.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

(pb_types.Type?, String) _resolveShip(BuildContext context, WidgetRef ref, int shipTypeId) {
  final shipType = ref.watch(repoCollectionProvider.select((c) => c?.getType(shipTypeId)));
  final locale = context.locale.languageCode;
  final shipName = shipType != null
      ? ref.watch(
              repoCollectionProvider.select(
                (c) => c?.getLocalizedName(shipType.typeName.id, locale),
              ),
            ) ??
            ""
      : "";
  return (shipType, shipName);
}

Future<void> showPriceDetailPage(BuildContext context, {required String fitId}) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (context) => PriceDetailPage(fitId: fitId)));

class PriceDetailPage extends ConsumerWidget {
  const PriceDetailPage({required this.fitId, super.key});

  final String fitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitState = ref.watch(fitProvider(fitId));
    if (!fitState.isInitialized) {
      return Scaffold(
        appBar: AppBar(),
        body: const SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final fit = fitState.fit;
    final shipTypeId = fit.body.shipTypeId;
    final (_, shipName) = _resolveShip(context, ref, shipTypeId);
    final title = context.l10n.priceDetailTitle(shipName: shipName, fitName: fit.metadata.name);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: _PriceBreakdownBody(
          fitId: fitId,
          shipTypeId: shipTypeId,
          fitName: fit.metadata.name,
        ),
      ),
    );
  }
}

class _PriceBreakdownBody extends ConsumerWidget {
  const _PriceBreakdownBody({required this.fitId, required this.shipTypeId, required this.fitName});

  final String fitId;
  final int shipTypeId;
  final String fitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakdown = ref.watch(fitPriceBreakdownProvider(fitId));

    return breakdown.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(context.l10n.priceDetailLoadFailed)),
      data: (value) {
        if (value == null) {
          return Center(child: Text(context.l10n.priceDetailNoData));
        }
        return _PriceBreakdownList(breakdown: value, shipTypeId: shipTypeId, fitName: fitName);
      },
    );
  }
}

class _PriceBreakdownList extends ConsumerWidget {
  const _PriceBreakdownList({
    required this.breakdown,
    required this.shipTypeId,
    required this.fitName,
  });

  final FitPriceBreakdown breakdown;
  final int shipTypeId;
  final String fitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);

    if (columns >= 2) {
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _HeaderTile(shipTypeId: shipTypeId, fitName: fitName),
          const SizedBox(height: 4),
          _SummarySection(breakdown: breakdown, columns: columns),
          const Divider(height: 16, indent: 16, endIndent: 16),
          _PriceItemTable(items: breakdown.items),
        ],
      );
    }

    return _SingleColumnTabs(breakdown: breakdown, shipTypeId: shipTypeId, fitName: fitName);
  }
}

class _HeaderTile extends ConsumerWidget {
  const _HeaderTile({required this.shipTypeId, required this.fitName});

  final int shipTypeId;
  final String fitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (shipType, shipName) = _resolveShip(context, ref, shipTypeId);

    return ListTile(
      minTileHeight: 0,
      leading: shipType != null ? EveIcon(icon: shipType.icon, size: 32) : null,
      title: Text(
        context.l10n.priceDetailTitle(shipName: shipName, fitName: fitName),
        style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.breakdown, required this.columns});

  final FitPriceBreakdown breakdown;
  final int columns;

  @override
  Widget build(BuildContext context) {
    // The labels are reversed relative to the breakdown fields because of the
    // way the breakdown is calculated. See its documentation for more details.
    final buy = _SummaryTile(
      label: context.l10n.priceDetailBuy,
      value: breakdown.totalSell,
      color: Colors.red.shade700,
    );
    final sell = _SummaryTile(
      label: context.l10n.priceDetailSell,
      value: breakdown.totalBuy,
      color: Colors.green.shade700,
    );

    if (columns >= 2) {
      return Row(
        children: [
          Expanded(child: buy),
          const VerticalDivider(indent: 8, endIndent: 8),
          Expanded(child: sell),
        ],
      );
    }
    return Column(children: [buy, sell]);
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.color});

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 0,
    minVerticalPadding: 4,
    title: Text(label, style: context.theme.textTheme.titleSmall),
    trailing: Text(
      value != null ? "${value!.commaSeparated} ISK" : context.l10n.priceDetailUnavailable,
      style: context.theme.textTheme.titleMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// The two price perspectives of a fit.
///
/// The mapping to the breakdown fields is intentionally reversed: the prices a
/// seller lists (`unitSell`/`totalSell`) are what it costs to *buy* the fit,
/// while the prices a buyer offers (`unitBuy`/`totalBuy`) are what one receives
/// when *selling* it. See [FitPriceBreakdown] for details.
enum _PriceSide {
  buy,
  sell;

  Color get color => switch (this) {
    _PriceSide.buy => Colors.red.shade700,
    _PriceSide.sell => Colors.green.shade700,
  };

  String label(BuildContext context) => switch (this) {
    _PriceSide.buy => context.l10n.priceDetailBuy,
    _PriceSide.sell => context.l10n.priceDetailSell,
  };

  double? unit(FitPriceLineItem item) => switch (this) {
    _PriceSide.buy => item.unitSell,
    _PriceSide.sell => item.unitBuy,
  };

  double? total(FitPriceLineItem item) => switch (this) {
    _PriceSide.buy => item.totalSell,
    _PriceSide.sell => item.totalBuy,
  };
}

class _SingleColumnTabs extends ConsumerStatefulWidget {
  const _SingleColumnTabs({
    required this.breakdown,
    required this.shipTypeId,
    required this.fitName,
  });

  final FitPriceBreakdown breakdown;
  final int shipTypeId;
  final String fitName;

  @override
  ConsumerState<_SingleColumnTabs> createState() => _SingleColumnTabsState();
}

class _SingleColumnTabsState extends ConsumerState<_SingleColumnTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _PriceSide.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _HeaderTile(shipTypeId: widget.shipTypeId, fitName: widget.fitName),
      _SummarySection(breakdown: widget.breakdown, columns: 1),
      TabBar(
        controller: _tabController,
        tabs: [for (final side in _PriceSide.values) Tab(text: side.label(context))],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            for (final side in _PriceSide.values)
              _SidePriceList(breakdown: widget.breakdown, side: side),
          ],
        ),
      ),
    ],
  );
}

class _SidePriceList extends StatelessWidget {
  const _SidePriceList({required this.breakdown, required this.side});

  final FitPriceBreakdown breakdown;
  final _PriceSide side;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 8),
    children: [for (final item in breakdown.items) _SideItemTile(item: item, side: side)],
  );
}

class _SideItemTile extends ConsumerWidget {
  const _SideItemTile({required this.item, required this.side});

  final FitPriceLineItem item;
  final _PriceSide side;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(item.typeId)));

    return ListTile(
      minTileHeight: 0,
      minVerticalPadding: 8,
      leading: type != null ? EveIcon(icon: type.icon) : null,
      title: type != null ? LocalizedTypeName(typeId: item.typeId) : Text("Type ${item.typeId}"),
      subtitle: item.quantity > 1
          ? Text(
              "x${item.quantity}",
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatIsk(context, side.total(item)),
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: side.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.quantity > 1)
            Text(
              _formatIsk(context, side.unit(item)),
              style: context.theme.textTheme.bodySmall?.copyWith(color: side.color),
            ),
        ],
      ),
      onLongPress: () => showItemDetailPage(context, typeId: item.typeId),
    );
  }
}

class _PriceItemTable extends ConsumerWidget {
  const _PriceItemTable({required this.items});

  final List<FitPriceLineItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DefaultTextStyle(
      style: const TextStyle(fontSize: 16),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(32),
          1: FlexColumnWidth(),
          2: IntrinsicColumnWidth(),
          3: IntrinsicColumnWidth(),
          4: IntrinsicColumnWidth(),
          5: IntrinsicColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          _buildHeaderRow(context),
          for (final item in items) _buildRow(context, ref, item),
        ],
      ),
    ),
  );

  TableRow _buildHeaderRow(BuildContext context) {
    final l10n = context.l10n;
    final sellColor = Colors.red.shade700;
    final buyColor = Colors.green.shade700;
    final style = context.theme.textTheme.labelSmall;

    Widget headerCell(String text, Color color) => Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        text,
        textAlign: TextAlign.end,
        style: style?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );

    return TableRow(
      children: [
        const SizedBox.shrink(),
        const SizedBox.shrink(),
        headerCell("${_PriceSide.buy.label(context)} ${l10n.priceDetailUnit}", sellColor),
        headerCell("${_PriceSide.buy.label(context)} ${l10n.priceDetailTotal}", sellColor),
        headerCell("${_PriceSide.sell.label(context)} ${l10n.priceDetailUnit}", buyColor),
        headerCell("${_PriceSide.sell.label(context)} ${l10n.priceDetailTotal}", buyColor),
      ],
    );
  }

  TableRow _buildRow(BuildContext context, WidgetRef ref, FitPriceLineItem item) {
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(item.typeId)));
    final sellColor = Colors.red.shade700;
    final buyColor = Colors.green.shade700;
    final icon = type != null ? EveIcon(icon: type.icon, size: 32) : const SizedBox.shrink();

    return TableRow(
      children: [
        icon,
        InkWell(
          onLongPress: () => showItemDetailPage(context, typeId: item.typeId),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Row(
              children: [
                Flexible(
                  child: type != null
                      ? LocalizedTypeName(typeId: item.typeId)
                      : Text("Type ${item.typeId}"),
                ),
                if (item.quantity > 1)
                  Text(
                    " x${item.quantity}",
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        _priceCell(context, item.unitSell, color: sellColor, emphasized: false),
        _priceCell(context, item.totalSell, color: sellColor, emphasized: true),
        _priceCell(context, item.unitBuy, color: buyColor, emphasized: false),
        _priceCell(context, item.totalBuy, color: buyColor, emphasized: true),
      ],
    );
  }

  Widget _priceCell(
    BuildContext context,
    double? price, {
    required Color color,
    required bool emphasized,
  }) => Padding(
    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
    child: Text(
      _formatIsk(context, price),
      textAlign: TextAlign.end,
      style: emphasized
          ? context.theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600)
          : context.theme.textTheme.bodySmall?.copyWith(color: color),
    ),
  );
}

String _formatIsk(BuildContext context, double? price) =>
    price != null ? "${price.commaSeparated} ISK" : context.l10n.priceDetailUnavailable;
