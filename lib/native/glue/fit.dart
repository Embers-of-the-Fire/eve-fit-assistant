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
      implant: _intoNativeImplants(fit.implant),
      skills: skills,
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
