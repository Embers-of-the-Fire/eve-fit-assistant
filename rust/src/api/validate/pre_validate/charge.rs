use eve_fit_os::provider::InfoProvider;

use crate::api::error::{ErrorKey, SlotType, WarningKey};

use crate::api::{error::SlotInfo, schema};

/// Volume
///
/// `volume`
pub(crate) const ATTR_VOLUME: i32 = 161;

/// Charge size
///
/// chargeSize
pub(crate) const ATTR_CHARGE_SIZE: i32 = 128;

/// Ammo Capacity
///
/// `capacity`
pub(crate) const ATTR_AMMO_CAP: i32 = 38;

pub(crate) fn validate_charge(
    fit: &schema::Fit,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    fn validate_single(
        item: &schema::Item,
        slot: SlotType,
        info: &impl InfoProvider,
        err: &mut Vec<SlotInfo>,
    ) {
        let dogma = info.get_dogma_attributes(item.item_id);
        let ammo_cap = dogma
            .iter()
            .find_map(|a| (a.attribute_id == ATTR_AMMO_CAP).then_some(a.value));
        if let Some(charge) = &item.charge {
            let charge_dogma = info.get_dogma_attributes(*charge);

            let charge_cap = charge_dogma
                .iter()
                .find_map(|a| (a.attribute_id == ATTR_VOLUME).then_some(a.value));
            if let (Some(cap), Some(ammo_cap)) = (charge_cap, ammo_cap) {
                if cap > ammo_cap {
                    err.push(SlotInfo::Error {
                        slot,
                        index: Some(item.index),
                        error_key: ErrorKey::IncompatibleChargeCapacity {
                            max: ammo_cap,
                            actual: cap,
                        },
                    });
                }
            }

            let charge_size = dogma
                .iter()
                .find_map(|a| (a.attribute_id == ATTR_CHARGE_SIZE).then_some(a.value));
            if let Some(charge_size) = charge_size {
                let charge_self_size = charge_dogma
                    .iter()
                    .find_map(|a| (a.attribute_id == ATTR_CHARGE_SIZE).then_some(a.value));
                let Some(charge_self_size) = charge_self_size else {
                    return;
                };

                if (charge_size as u8) != (charge_self_size as u8) {
                    err.push(SlotInfo::Error {
                        slot,
                        index: Some(item.index),
                        error_key: ErrorKey::IncompatibleChargeSize {
                            expected: charge_size as u8,
                            actual: charge_self_size as u8,
                        },
                    });
                }
            }
        } else if ammo_cap.is_some() {
            err.push(SlotInfo::Warning {
                slot,
                index: Some(item.index),
                warning_key: WarningKey::MissingCharge,
            });
        }
    }

    for item in &fit.modules.high {
        validate_single(item, SlotType::High, info, err);
    }
    for item in &fit.modules.medium {
        validate_single(item, SlotType::Medium, info, err);
    }
    for item in &fit.modules.low {
        validate_single(item, SlotType::Low, info, err);
    }
}
