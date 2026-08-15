import "package:eve_fit_assistant/features/market_price/state/state.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFit({
  IList<Option<FitModuleItem>>? high,
  IList<FitDroneItem> drones = const IListConst([]),
  IList<FitFighterItem> fighters = const IListConst([]),
  IList<FitImplantItem> implants = const IListConst([]),
  IList<FitBoosterItem> boosters = const IListConst([]),
  IMap<int, FitDynamicItem> dynamicItems = const IMapConst({}),
}) => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit",
    shipTypeId: 587,
    name: "Test",
    lastModified: 0,
    description: "",
    checkoutRef: const CheckoutRef(checkoutId: "checkout", serverId: "tranquility"),
  ),
  body: FitStorageBody(
    shipTypeId: 587,
    characterId: "character",
    damageProfile: const FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: high ?? const IListConst([]),
      medium: const IListConst([]),
      low: const IListConst([]),
      rig: const IListConst([]),
      subsystem: const IListConst([]),
      service: const IListConst([]),
      tacticalMode: const Option.none(),
    ),
    drones: drones,
    fighters: fighters,
    implants: implants,
    boosters: boosters,
  ),
  dynamicRegistry: FitDynamicRegistry(dynamicItems: dynamicItems),
);

FitModuleItem _module(int typeId, {int? chargeTypeId}) => FitModuleItem(
  itemId: FitStorageItemId.item(id: typeId),
  state: FitItemState.active,
  charge: chargeTypeId == null
      ? const Option.none()
      : Option.of(FitChargeItem(typeId: chargeTypeId)),
);

void main() {
  group("collectFitTypeQuantities", () {
    test("always includes the hull", () {
      final quantities = collectFitTypeQuantities(_makeFit());
      expect(quantities, {587: 1});
    });

    test("counts modules and charges once each", () {
      final quantities = collectFitTypeQuantities(
        _makeFit(
          high: IList([
            Option.of(_module(10629, chargeTypeId: 203)),
            Option.of(_module(10629)),
            const Option.none(),
          ]),
        ),
      );
      expect(quantities, {587: 1, 10629: 2, 203: 1});
    });

    test("counts drones and fighters by quantity", () {
      final quantities = collectFitTypeQuantities(
        _makeFit(
          drones: IList([
            FitDroneItem(
              itemId: const FitStorageItemId.item(id: 2488),
              state: FitItemState.active,
              quantity: 5,
            ),
          ]),
          fighters: IList([
            FitFighterItem(
              itemId: const FitStorageItemId.item(id: 40557),
              groupId: 0,
              quantity: 3,
              fighterAbility: 0,
            ),
          ]),
        ),
      );
      expect(quantities[2488], 5);
      expect(quantities[40557], 3);
    });

    test("counts implants and boosters once each", () {
      final quantities = collectFitTypeQuantities(
        _makeFit(
          implants: IList([
            const FitImplantItem(
              itemId: FitStorageItemId.item(id: 13244),
              state: FitItemState.online,
            ),
          ]),
          boosters: IList([
            const FitBoosterItem(
              itemId: FitStorageItemId.item(id: 28668),
              index: 1,
              state: FitItemState.online,
            ),
          ]),
        ),
      );
      expect(quantities[13244], 1);
      expect(quantities[28668], 1);
    });

    test("resolves dynamic items to their resulting type", () {
      final quantities = collectFitTypeQuantities(
        _makeFit(
          high: IList([
            Option.of(
              const FitModuleItem(
                itemId: FitStorageItemId.dynamic(dynamicId: 0),
                state: FitItemState.active,
                charge: Option.none(),
              ),
            ),
          ]),
          dynamicItems: const IMapConst({
            0: FitDynamicItem(
              dynamicItemId: 0,
              originTypeId: 10629,
              typeId: 47200,
              modifierTypeId: 4788,
              dynamicAttributes: IMapConst({}),
            ),
          }),
        ),
      );
      expect(quantities, {587: 1, 47200: 1});
    });

    test("skips unresolved dynamic references", () {
      final quantities = collectFitTypeQuantities(
        _makeFit(
          high: IList([
            Option.of(
              const FitModuleItem(
                itemId: FitStorageItemId.dynamic(dynamicId: 99),
                state: FitItemState.active,
                charge: Option.none(),
              ),
            ),
          ]),
        ),
      );
      expect(quantities, {587: 1});
    });
  });
}
