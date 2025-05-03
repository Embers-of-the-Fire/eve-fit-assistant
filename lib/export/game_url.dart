import 'package:animated_tree_view/helpers/collection_utils.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

String exportToGameUrl(FitRecord fit) {
  String url = '';

  url += 'fitting:${fit.body.shipID}:';

  final Map<int, int> items = {};
  for (final item in [fit.body.high, fit.body.med, fit.body.low, fit.body.rig, fit.body.subsystem]
      .flatten()
      .filterNotNull()) {
    if (item.isDynamic) {
      final typeID = GlobalStorage()
          .static
          .dynamicItems[fit.body.dynamicItems[item.itemID]!.mutaplasmidID]
          ?.data
          .inputOutputMapping
          .resultingType;
      if (typeID != null) {
        items[typeID] = (items[typeID] ?? 0) + 1;
      }
    } else {
      items[item.itemID] = (items[item.itemID] ?? 0) + 1;
    }
    if (item.chargeID != null) {
      items[item.chargeID!] = (items[item.chargeID!] ?? 0) + 1;
    }
  }
  for (final item in fit.body.drone) {
    items[item.itemID] = (items[item.itemID] ?? 0) + item.amount;
  }
  for (final item in fit.body.fighter) {
    items[item.itemID] = (items[item.itemID] ?? 0) + item.amount;
  }
  url += items.entries.map((e) => '${e.key};${e.value}').join(':');

  url += '::';
  return '<a href="$url">'
      '[${GlobalStorage().static.types[fit.body.shipID]!.nameZH}] ${fit.brief.name}'
      '</a>';
}
