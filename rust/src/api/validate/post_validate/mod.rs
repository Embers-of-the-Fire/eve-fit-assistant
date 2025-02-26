use eve_fit_os::provider::InfoProvider;

use crate::api::{error::SlotInfo, proxy::ShipProxy};

pub(crate) mod charge;
pub(crate) mod max_activate;

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn post_validate(fit: &ShipProxy, info: &impl InfoProvider, err: &mut Vec<SlotInfo>) {
    charge::validate_charge(fit, info, err);
    max_activate::validate_max_active_group(fit, info, err);
}
