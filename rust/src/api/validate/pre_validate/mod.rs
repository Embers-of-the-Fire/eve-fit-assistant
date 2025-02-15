use eve_fit_os::provider::InfoProvider;

use crate::api::{error::SlotInfo, schema};

pub(crate) mod charge;

pub(crate) mod slot_num;

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn pre_validate(fit: &schema::Fit, info: &impl InfoProvider) -> Vec<SlotInfo> {
    let mut err = vec![];

    charge::validate_charge(fit, info, &mut err);
    slot_num::validate_slot_num(fit, info, &mut err);

    err
}
