import 'package:animated_tree_view/helpers/collection_utils.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

String exportToEft(FitRecord fit) {
  // header
  final header =
      '[${GlobalStorage().static.types[fit.body.shipID]!.nameZH}, ${fit.brief.name}]\n\n';

  final List<String> body = [];
  // modules
  final List<String> modules = [];
  // record data: origin type ID, mutaplasmid ID, dynamic data
  final List<(int, int, Map<int, double>)> dynamicRecords = [];
  for (final (slots, placeholder) in [
    (fit.body.low, '[Empty Low slot]'),
    (fit.body.med, '[Empty Med slot]'),
    (fit.body.high, '[Empty High slot]'),
    (fit.body.rig, '[Empty Rig slot]'),
    (fit.body.subsystem, '[Empty Subsystem slot]'),
  ]) {
    final List<String> text = [];
    for (final item in slots) {
      if (item == null) {
        text.add(placeholder);
        continue;
      }
      late final String itemName;
      late final int? dynIndex;
      if (item.isDynamic) {
        final dynType = fit.body.dynamicItems[item.itemID]!;
        final index = dynamicRecords.length + 1;
        dynamicRecords.add((dynType.baseType, dynType.mutaplasmidID, dynType.dynamicAttributes));
        itemName = GlobalStorage().static.types[dynType.baseType]!.nameZH;
        dynIndex = index;
      } else {
        itemName = GlobalStorage().static.types[item.itemID]!.nameZH;
        dynIndex = null;
      }
      final chargeName =
          item.chargeID != null ? GlobalStorage().static.types[item.chargeID!]!.nameZH : null;
      text.add(
        '$itemName'
        '${chargeName != null ? ', $chargeName' : ''}'
        '${dynIndex != null ? ' [$dynIndex]' : ''}',
      );
    }
    if (text.isNotEmpty) modules.add(text.join('\n'));
  }
  if (modules.isNotEmpty) body.add(modules.join('\n\n'));

  // drones & fighters
  final List<String> minions = [];
  // drone
  final droneOrder = [
    837, // Light Scout Drones 轻型侦察无人机
    838, // Medium Scout Drones 中型侦察无人机
    359, // Heavy Attack Drones 重型攻击无人机
    911, // Sentry Drones 岗哨无人机
    843, // Combat Utility Drones 功能性战斗无人机
    841, // Electronic Warfare Drones 电子战无人机
    842, // Logistic Drones 后勤无人机
    158, // Mining Drones 采矿无人机
    1643, // Salvage Drones 打捞无人机
  ];
  final drones = fit.body.drone
      .sortedByKey<num>((drone) =>
          droneOrder.indexOf(GlobalStorage().static.types[drone.itemID]?.marketGroupID ?? 0))
      .map((drone) => '${GlobalStorage().static.types[drone.itemID]!.nameZH} x${drone.amount}')
      .toList(growable: false);
  if (drones.isNotEmpty) minions.add(drones.join('\n'));
  // fighter
  final fighterOrder = [
    1652, // Light Fighter 轻型铁骑舰载机
    4777, // Structure Light Fighter 建筑轻型铁骑舰载机
    1653, // Heavy Fighter 重型铁骑舰载机
    4779, // Structure Heavy Fighter 建筑重型铁骑舰载机
    1537, // Support Fighter 后勤铁骑舰载机
    4778, // Structure Support Fighter 建筑后勤铁骑舰载机
  ];
  final fighters = fit.body.fighter
      .sortedByKey<num>((drone) =>
          fighterOrder.indexOf(GlobalStorage().static.types[drone.itemID]?.marketGroupID ?? 0))
      .map((drone) => '${GlobalStorage().static.types[drone.itemID]!.nameZH} x${drone.amount}')
      .toList(growable: false);
  if (fighters.isNotEmpty) minions.add(fighters.join('\n'));
  if (minions.isNotEmpty) body.add(minions.join('\n\n'));

  // implants & boosters
  final List<String> chars = [];
  // implants
  final implants = fit.body.implant
      .filterNotNull()
      .map((implant) => GlobalStorage().static.types[implant.itemID]!.nameZH)
      .toList(growable: false);
  if (implants.isNotEmpty) chars.add(implants.join('\n'));
  // boosters
  final boosters = fit.body.booster
      .filterNotNull()
      .map((booster) => GlobalStorage().static.types[booster.itemID]!.nameZH)
      .toList(growable: false);
  if (boosters.isNotEmpty) chars.add(boosters.join('\n'));
  if (chars.isNotEmpty) body.add(chars.join('\n\n'));

  // dynamic records
  final List<String> dynamicRecordsText = [];
  for (final (index, (origID, mutID, dynData)) in dynamicRecords.enumerate()) {
    dynamicRecordsText.add(
      '[${index + 1}] ${GlobalStorage().static.types[origID]!.nameZH}\n'
      '  ${GlobalStorage().static.types[mutID]!.nameZH}\n'
      '  ${dynData.entries.map((e) => '${GlobalStorage().static.attributes[e.key]!.name}'
          ' ${e.value.toStringAsMaxDecimals(4)}').join(', ')}',
    );
  }
  if (dynamicRecordsText.isNotEmpty) body.add(dynamicRecordsText.join('\n'));

  return header + body.join('\n\n\n');
}
