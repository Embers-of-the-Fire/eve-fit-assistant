use eve_fit_os::{fit::Type, provider::InfoProvider};

use crate::api::{
    error::{ErrorKey, SlotInfo, SlotType},
    schema::{self, Item},
};

pub(crate) const CAN_FIT_GROUP_ATTR_IDS: [i32; 20] = [
    1298, 1299, 1300, 1301, 1872, 1879, 1880, 1881, 2065, 2396, 2476, 2477, 2478, 2479, 2480, 2481,
    2482, 2483, 2484, 2485,
];
pub(crate) const CAN_FIT_TYPE_ATTR_IDS: [i32; 11] = [
    1302, 1303, 1304, 1305, 1944, 2103, 2463, 2486, 2487, 2488, 2758,
];

pub(crate) fn validate_fit_target(
    fit: &schema::Fit,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    fn validate_item(
        ship_id: i32,
        ship_type: Type,
        item: &Item,
        slot: SlotType,
        index: i32,
        info: &impl InfoProvider,
        err: &mut Vec<SlotInfo>,
    ) {
        fn get_fit_groups(item_id: i32, info: &impl InfoProvider) -> impl Iterator<Item = i32> {
            info.get_dogma_attributes(item_id)
                .into_iter()
                .filter(|t| CAN_FIT_GROUP_ATTR_IDS.contains(&t.attribute_id))
                .map(|t| t.value as i32)
                .filter(|&t| t != 0)
        }

        let groups = get_fit_groups(item.item_id, info).collect::<Vec<_>>();
        let group_contains = groups.iter().any(|&t| t == ship_type.group_id);

        fn get_fit_types(item_id: i32, info: &impl InfoProvider) -> impl Iterator<Item = i32> {
            info.get_dogma_attributes(item_id)
                .into_iter()
                .filter(|t| CAN_FIT_TYPE_ATTR_IDS.contains(&t.attribute_id))
                .map(|t| t.value as i32)
                .filter(|&t| t != 0)
        }

        let types = get_fit_types(item.item_id, info).collect::<Vec<_>>();
        let types_contains = types.iter().any(|&t| t == ship_id);

        if !(types_contains || group_contains || (groups.is_empty() && types.is_empty())) {
            if !groups.is_empty() {
                err.push(SlotInfo::Error {
                    slot,
                    index: Some(index),
                    error_key: ErrorKey::IncompatibleShipGroup { expected: groups },
                });
            }
            if !types.is_empty() {
                err.push(SlotInfo::Error {
                    slot,
                    index: Some(index),
                    error_key: ErrorKey::IncompatibleShipType { expected: types },
                });
            }
        }
    }

    let ty = info.get_type(fit.ship_id);

    [
        (&fit.modules.high, SlotType::High),
        (&fit.modules.medium, SlotType::Medium),
        (&fit.modules.low, SlotType::Low),
        (&fit.modules.rig, SlotType::Rig),
        (&fit.modules.subsystem, SlotType::Subsystem),
    ]
    .into_iter()
    .flat_map(|(v, i)| v.iter().enumerate().map(move |t| (t, i)))
    .for_each(|((index, item), slot)| {
        validate_item(fit.ship_id, ty, item, slot, index as i32, info, err);
    });
}
