use eve_fit_os::provider::InfoProvider;

use crate::api::{error::{ErrorKey, SlotInfo, SlotType}, schema};

pub(crate) const RIG_SIZE_ATTR_ID: i32 = 1547;

pub(crate) fn validate_rig_size(
    fit: &schema::Fit,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    let ship_rig = info
        .get_dogma_attributes(fit.ship_id)
        .into_iter()
        .find(|t| t.attribute_id == RIG_SIZE_ATTR_ID)
        .map(|t| t.value as u8);

    for (index, rig) in fit.modules.rig.iter().enumerate() {
        let rig_size = info
            .get_dogma_attributes(rig.item_id)
            .into_iter()
            .find(|t| t.attribute_id == RIG_SIZE_ATTR_ID)
            .map(|t| t.value as u8);
        
        if let (Some(ship), Some(rig)) = (ship_rig, rig_size) {
            if ship != rig {
                err.push(SlotInfo::Error {
                    slot: SlotType::Rig,
                    index: Some(index as i32),
                    error_key: ErrorKey::IncompatibleRigSize {
                        expected: ship,
                        actual: rig,
                    },
                });
            }
        }
    }
}
