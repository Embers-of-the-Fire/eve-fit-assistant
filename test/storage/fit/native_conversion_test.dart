import "package:eve_fit_assistant/native/api/storage.dart" as native;
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitModuleItem _module(int typeId, FitItemState state) => FitModuleItem(
  itemId: FitStorageItemId.item(id: typeId),
  state: state,
  charge: const None(),
);

FitStorage _makeFit() => FitStorage(
  metadata: const FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 1234,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 1234,
    characterId: "predefined_all_5",
    damageProfile: const FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList([Some(_module(100, FitItemState.active))]),
      medium: const IList.empty(),
      low: IList([Some(_module(300, FitItemState.online))]),
      rig: IList([
        Some(_module(200, FitItemState.passive)),
        Some(_module(201, FitItemState.online)),
      ]),
      subsystem: const IList.empty(),
      service: const IList.empty(),
      tacticalMode: const None(),
    ),
    drones: const IList.empty(),
    fighters: const IList.empty(),
    implants: const IList.empty(),
    boosters: const IList.empty(),
  ),
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

void main() {
  group("convertModulesToNative", () {
    test("excludes passive rigs but keeps all subsequent modules", () {
      final modules = convertModulesToNative(_makeFit());

      expect(
        modules.where((m) => m.slot.slotType == native.SlotType.rig && m.slot.index == 0),
        isEmpty,
      );
      expect(modules.singleWhere((m) => m.slot.slotType == native.SlotType.rig).slot.index, 1);
      expect(modules.where((m) => m.slot.slotType == native.SlotType.high), hasLength(1));
      expect(modules.where((m) => m.slot.slotType == native.SlotType.low), hasLength(1));
      expect(modules, hasLength(3));
    });

    test("passive non-rig modules are still sent to the simulator", () {
      final fit = _makeFit();
      final withPassiveHigh = fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(high: IList([Some(_module(100, FitItemState.passive))])),
        ),
      );

      final modules = convertModulesToNative(withPassiveHigh);
      expect(
        modules.singleWhere((m) => m.slot.slotType == native.SlotType.high).state,
        native.State.passive,
      );
    });
  });
}
