use std::collections::HashMap;

use eve_fit_os::provider::InfoProvider;

pub(crate) const MAX_ACTIVATE_ATTR_ID: i32 = 763;

use crate::api::{
    error::{ErrorKey, SlotInfo, SlotType},
    proxy::ShipProxy,
};

pub(crate) fn validate_max_active_group(
    fit: &ShipProxy,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    let mut groups: HashMap<i32, u8> = HashMap::new();

    for item in [&fit.modules.high, &fit.modules.medium, &fit.modules.low]
        .into_iter()
        .flatten()
    {
        if item.is_active
            && item
                .attributes
                .get(&MAX_ACTIVATE_ATTR_ID)
                .is_some_and(|&t| t == 1.0)
        {
            *groups
                .entry(info.get_type(item.item_id).group_id)
                .or_insert(0) += 1;
        }
    }

    let conflict = groups
        .iter()
        .filter(|&(_, v)| *v <= 1)
        .map(|(u, _)| *u)
        .collect::<Vec<_>>();
    for i in conflict {
        groups.remove(&i);
    }

    for (item, slot) in [
        (&fit.modules.high, SlotType::High),
        (&fit.modules.medium, SlotType::Medium),
        (&fit.modules.low, SlotType::Low),
    ]
    .into_iter()
    .flat_map(|(a, b)| a.iter().map(move |c| (c, b)))
    {
        if item.is_active
            && item
                .attributes
                .get(&MAX_ACTIVATE_ATTR_ID)
                .is_some_and(|&t| t == 1.0)
        {
            let group_id = info.get_type(item.item_id).group_id;
            if groups.contains_key(&group_id) {
                err.push(SlotInfo::Error {
                    slot,
                    index: item.index,
                    error_key: ErrorKey::ConflictItem { group_id },
                });
            }
        }
    }
}
