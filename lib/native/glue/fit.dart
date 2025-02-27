import 'package:eve_fit_assistant/native/port/api/schema.dart' as schema;
import 'package:eve_fit_assistant/storage/fit/fit.dart' as local;
import 'package:eve_fit_assistant/utils/utils.dart';

schema.Fit intoNativeFit({required local.Fit fit, required Map<int, int> skills}) => schema.Fit(
      shipId: fit.shipID,
      damageProfile: schema.DamageProfile(
        em: fit.damageProfile.em,
        explosive: fit.damageProfile.explosive,
        kinetic: fit.damageProfile.kinetic,
        thermal: fit.damageProfile.thermal,
      ),
      modules: _intoNativeModules(fit),
      drones: _intoNativeDrones(fit.drone),
      fighters: _intoNativeFighters(fit.fighter),
      implant: _intoNativeImplants(fit.implant),
      skills: skills,
      dynamicItems: fit.dynamicItems.map((key, value) => MapEntry(
          key,
          schema.DynamicItem(
            baseType: value.baseType,
            dynamicAttributes: value.dynamicAttributes,
          ))),
    );

schema.Module _intoNativeModules(local.Fit fit) => schema.Module(
    high: _intoNativeItems(fit.high),
    medium: _intoNativeItems(fit.med),
    low: _intoNativeItems(fit.low),
    rig: _intoNativeItems(fit.rig),
    subsystem: _intoNativeItems(fit.subsystem),
    tacticalMode: fit.tacticalModeID.map((id) => _intoNativeItem(
          item: local.SlotItem(itemID: id, chargeID: null, state: local.SlotState.active),
          index: 0,
        )));

List<schema.Item> _intoNativeItems(List<local.SlotItem?> items) => items.enumerate().filterMap((e) {
      if (e.$2 == null || e.$2?.state == local.SlotState.passive) return null;
      return _intoNativeItem(item: e.$2!, index: e.$1);
    }).toList();

schema.Item _intoNativeItem({required local.SlotItem item, required int index}) => schema.Item(
      itemId: item.itemID,
      isDynamic: item.isDynamic,
      charge: item.chargeID,
      state: _intoNativeState(item.state),
      index: index,
    );

List<schema.DroneGroup> _intoNativeDrones(List<local.DroneItem> items) =>
    items.enumerate().filterMap((e) {
      if (e.$2.state == local.DroneState.passive) return null;
      return _intoNativeDrone(item: e.$2, index: e.$1);
    }).toList();

schema.DroneGroup _intoNativeDrone({required local.DroneItem item, required int index}) =>
    schema.DroneGroup(
      itemId: item.itemID,
      amount: item.amount,
      index: index,
    );

List<schema.FighterGroup> _intoNativeFighters(List<local.FighterItem> items) =>
    items.enumerate().filterMap((e) {
      if (e.$2.state == local.DroneState.passive) return null;
      return _intoNativeFighter(item: e.$2, index: e.$1);
    }).toList();

schema.FighterGroup _intoNativeFighter({required local.FighterItem item, required int index}) =>
    schema.FighterGroup(
      itemId: item.itemID,
      amount: item.amount,
      index: index,
      ability: item.ability,
    );

List<schema.Implant> _intoNativeImplants(List<local.SlotItem?> items) =>
    items.enumerate().filterMap((e) {
      if (e.$2 == null) return null;
      return _intoNativeImplant(item: e.$2!, index: e.$1);
    }).toList();

schema.Implant _intoNativeImplant({required local.SlotItem item, required int index}) =>
    schema.Implant(
      itemId: item.itemID,
      index: index,
    );

schema.ItemState _intoNativeState(local.SlotState state) {
  switch (state) {
    case local.SlotState.passive:
      return schema.ItemState.passive;
    case local.SlotState.online:
      return schema.ItemState.online;
    case local.SlotState.active:
      return schema.ItemState.active;
    case local.SlotState.overload:
      return schema.ItemState.overload;
  }
}

const fighterAbilityAttackTurret = 1; // 0b0000_0001
const fighterAbilityMissiles = 2; // 0b0000_0010
const fighterAbilityAttackMissile = 4; // 0b0000_0100
const fighterAbilityBomb = 8; // 0b0000_1000
