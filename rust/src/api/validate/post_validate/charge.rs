use eve_fit_os::provider::InfoProvider;

use crate::api::error::{ErrorKey, WarningKey};
use crate::api::error::{SlotInfo, SlotType};
use crate::api::proxy::{ItemProxy, ShipProxy};

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

pub(crate) fn validate_charge(fit: &ShipProxy, info: &impl InfoProvider, err: &mut Vec<SlotInfo>) {
    fn validate_single(
        item: &ItemProxy,
        slot: SlotType,
        _info: &impl InfoProvider,
        err: &mut Vec<SlotInfo>,
    ) {
        let ammo_cap = item.attributes.blocking_read().get_by_id(ATTR_AMMO_CAP);
        if let Some(charge) = &item.charge {
            let charge_cap = charge.attributes.blocking_read().get_by_id(ATTR_VOLUME);
            if let (Some(cap), Some(ammo_cap)) = (charge_cap, ammo_cap) {
                if cap > ammo_cap {
                    err.push(SlotInfo::Error {
                        slot,
                        index: item.index,
                        error_key: ErrorKey::IncompatibleChargeCapacity {
                            max: ammo_cap,
                            actual: cap,
                        },
                    });
                }
            }

            let charge_size = item.attributes.blocking_read().get_by_id(ATTR_CHARGE_SIZE);
            if let Some(charge_size) = charge_size {
                let charge_self_size = charge
                    .attributes
                    .blocking_read()
                    .get_by_id(ATTR_CHARGE_SIZE);
                let Some(charge_self_size) = charge_self_size else {
                    return;
                };

                if (charge_size as u8) != (charge_self_size as u8) {
                    err.push(SlotInfo::Error {
                        slot,
                        index: item.index,
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
                index: item.index,
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
