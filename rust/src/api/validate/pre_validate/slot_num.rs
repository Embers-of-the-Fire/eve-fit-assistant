use eve_fit_os::provider::InfoProvider;

use crate::api::{
    error::{ErrorKey, SlotInfo, SlotType},
    schema,
};

pub(crate) const EFFECT_LAUNCHER: i32 = 40;
pub(crate) const EFFECT_TURRET: i32 = 42;

pub(crate) const ATTR_TURRET: i32 = 102;
pub(crate) const ATTR_LAUNCHER: i32 = 101;

pub(crate) const ATTR_SUBSYSTEM_TURRET: i32 = 1368;
pub(crate) const ATTR_SUBSYSTEM_LAUNCHER: i32 = 1369;

pub(crate) fn validate_slot_num(
    fit: &schema::Fit,
    info: &impl InfoProvider,
    err: &mut Vec<SlotInfo>,
) {
    fn get_slot_turret_or_launcher(item: &schema::Item, info: &impl InfoProvider) -> (u8, u8) {
        let dogma = info.get_dogma_effects(item.item_id);
        for effect in dogma {
            if effect.effect_id == EFFECT_TURRET {
                return (1, 0);
            } else if effect.effect_id == EFFECT_LAUNCHER {
                return (0, 1);
            }
        }
        (0, 0)
    }

    let (actual_turret, actual_launcher) = fit
        .modules
        .high
        .iter()
        .map(|i| get_slot_turret_or_launcher(i, info))
        .reduce(|(a, b), (a2, b2)| (a + a2, b + b2))
        .unwrap_or((0, 0));

    let ship_dogma = info.get_dogma_attributes(fit.ship_id);
    let mut turret = ship_dogma
        .iter()
        .find_map(|a| (a.attribute_id == ATTR_TURRET).then_some(a.value))
        .unwrap_or(0.0) as u8;
    let mut launcher = ship_dogma
        .iter()
        .find_map(|a| (a.attribute_id == ATTR_LAUNCHER).then_some(a.value))
        .unwrap_or(0.0) as u8;

    for sub in &fit.modules.subsystem {
        let dogma = info.get_dogma_attributes(sub.item_id);
        turret += dogma
            .iter()
            .find_map(|a| (a.attribute_id == ATTR_SUBSYSTEM_TURRET).then_some(a.value))
            .unwrap_or(0.0) as u8;
        launcher += dogma
            .iter()
            .find_map(|a| (a.attribute_id == ATTR_SUBSYSTEM_LAUNCHER).then_some(a.value))
            .unwrap_or(0.0) as u8;
    }

    if actual_turret > turret {
        err.push(SlotInfo::Error {
            slot: SlotType::High,
            index: None,
            error_key: ErrorKey::TooMuchTurret {
                expected: turret,
                actual: actual_turret,
            },
        });
    }
    if actual_launcher > launcher {
        err.push(SlotInfo::Error {
            slot: SlotType::High,
            index: None,
            error_key: ErrorKey::TooMuchLauncher {
                expected: launcher,
                actual: actual_launcher,
            },
        });
    }
}
