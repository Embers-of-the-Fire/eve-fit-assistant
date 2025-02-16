use eve_fit_os::provider::InfoProvider;

use crate::api::{error::SlotInfo, schema};

pub(crate) mod slot_num;

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn pre_validate(fit: &schema::Fit, info: &impl InfoProvider, err: &mut Vec<SlotInfo>) {
    slot_num::validate_slot_num(fit, info, err);
}
