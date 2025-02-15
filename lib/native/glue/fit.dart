import 'package:eve_fit_assistant/native/port/api/schema.dart' as schema;
import 'package:eve_fit_assistant/storage/fit/fit.dart' as local;
import 'package:eve_fit_assistant/utils/itertools.dart';
import 'package:eve_fit_assistant/utils/optional.dart';

schema.Fit intoNativeFit({required local.Fit fit, required Map<int, int> skills}) {
  return schema.Fit(
    shipId: fit.shipID,
    modules: _intoNativeModules(fit),
    drones: _intoNativeDrones(fit.drone),
    implant: _intoNativeImplants(fit.implant),
    skills: skills,
  );
}

schema.Module _intoNativeModules(local.Fit fit) {
  return schema.Module(
      high: _intoNativeItems(fit.high),
      medium: _intoNativeItems(fit.med),
      low: _intoNativeItems(fit.low),
      rig: _intoNativeItems(fit.rig),
      subsystem: _intoNativeItems(fit.subsystem),
      tacticalMode: fit.tacticalModeID.map((id) => _intoNativeItem(
            item: local.SlotItem(itemID: id, chargeID: null, state: local.SlotState.active),
            index: 0,
          )));
}

List<schema.Item> _intoNativeItems(List<local.SlotItem?> items) {
  return items.enumerate().filterMap((e) {
    if (e.$2 == null) return null;
    return _intoNativeItem(item: e.$2!, index: e.$1);
  }).toList();
}

schema.Item _intoNativeItem({required local.SlotItem item, required int index}) {
  return schema.Item(
    itemId: item.itemID,
    charge: item.chargeID,
    state: _intoNativeState(item.state),
    index: index,
  );
}

List<schema.DroneGroup> _intoNativeDrones(List<local.DroneItem> items) {
  return items.enumerate().filterMap((e) {
    if (e.$2.state == local.DroneState.passive) return null;
    return _intoNativeDrone(item: e.$2, index: e.$1);
  }).toList();
}

schema.DroneGroup _intoNativeDrone({required local.DroneItem item, required int index}) {
  return schema.DroneGroup(
    itemId: item.itemID,
    amount: item.amount,
    index: index,
  );
}

List<schema.Implant> _intoNativeImplants(List<local.SlotItem?> items) {
  return items.enumerate().filterMap((e) {
    if (e.$2 == null) return null;
    return _intoNativeImplant(item: e.$2!, index: e.$1);
  }).toList();
}

schema.Implant _intoNativeImplant({required local.SlotItem item, required int index}) {
  return schema.Implant(
    itemId: item.itemID,
    index: index,
  );
}

schema.State _intoNativeState(local.SlotState state) {
  switch (state) {
    case local.SlotState.passive:
      return schema.State.passive;
    case local.SlotState.online:
      return schema.State.online;
    case local.SlotState.active:
      return schema.State.active;
    case local.SlotState.overload:
      return schema.State.overload;
  }
}
