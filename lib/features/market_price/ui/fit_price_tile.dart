import "package:eve_fit_assistant/features/market_price/state/state.dart";
import "package:eve_fit_assistant/features/market_price/ui/price_detail_page.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/num.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Estimated total price of a fit, shown at the end of the Attributes tab.
///
/// Always rendered; while the price is unavailable (still loading, feature
/// disabled, or no type yielded a price) a skeleton placeholder stands in for
/// the value.
class FitPriceTile extends ConsumerWidget {
  const FitPriceTile({required this.fitId, super.key});

  final String fitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref
        .watch(fitEstimatedPriceProvider(fitId))
        .when(data: (value) => value, loading: () => null, error: (_, _) => null);

    return ListTile(
      minTileHeight: 0,
      leading: const Icon(Icons.attach_money, size: 28),
      title: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.end,
        child: summary != null
            ? Text("${summary.total.commaSeparated} ISK")
            : Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 140,
                  height: 18,
                  decoration: BoxDecoration(
                    color: context.theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
      ),
      onLongPress: () => showPriceDetailPage(context, fitId: fitId),
    );
  }
}
