use eve_fit_os::provider::InfoProvider;

use crate::api::{error::SlotInfo, schema};

pub(crate) mod slot_num;
pub(crate) mod fit_target;
pub(crate) mod rig_size;
pub(crate) mod booster_slot;

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn pre_validate(fit: &schema::Fit, info: &impl InfoProvider, err: &mut Vec<SlotInfo>) {
    slot_num::validate_slot_num(fit, info, err);
    fit_target::validate_fit_target(fit, info, err);
    rig_size::validate_rig_size(fit, info, err);
    booster_slot::validate_booster_slot(fit, info, err);
}
