use std::collections::HashMap;

use eve_fit_os::provider::InfoProvider;

use crate::api::{
    error::{ErrorKey, SlotInfo, SlotType},
    schema,
};

pub(crate) const BOOSTER_SLOT_ATTR_ID: i32 = 1087;

pub(crate) fn validate_booster_slot(
    fit: &schema::Fit,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    let mut slots: HashMap<i32, usize> = HashMap::with_capacity(10);
    for booster in &fit.boosters {
        let slot = info
            .get_dogma_attributes(booster.item_id)
            .into_iter()
            .find(|t| t.attribute_id == BOOSTER_SLOT_ATTR_ID)
            .map(|t| t.value as i32);
        if let Some(slot) = slot {
            *slots.entry(slot).or_default() += 1;
        }
    }

    for booster in &fit.boosters {
        let slot = info
            .get_dogma_attributes(booster.item_id)
            .into_iter()
            .find(|t| t.attribute_id == BOOSTER_SLOT_ATTR_ID)
            .map(|t| t.value as i32);
        if let Some(slot) = slot {
            if slots.get(&slot).is_some_and(|&u| u > 1) {
                err.push(SlotInfo::Error {
                    slot: SlotType::Booster,
                    index: Some(booster.index),
                    error_key: ErrorKey::DuplicateBooster { slot },
                });
            }
        }
    }
}
