use std::collections::HashMap;

use eve_fit_os::{fit::ItemSlotType, provider::InfoProvider};

use crate::api::{
    output::{Item, Ship},
    storage::{FitStorage, ItemID},
};

const EFFECT_LAUNCHER: i32 = 40;
const EFFECT_TURRET: i32 = 42;

const ATTR_LAUNCHER: i32 = 101;
const ATTR_TURRET: i32 = 102;
const ATTR_CHARGE_SIZE: i32 = 128;
const ATTR_VOLUME: i32 = 161;
const ATTR_AMMO_CAPACITY: i32 = 38;
const ATTR_MAX_ACTIVE: i32 = 763;
const ATTR_BOOSTER_SLOT: i32 = 1087;
const ATTR_SUBSYSTEM_TURRET: i32 = 1368;
const ATTR_SUBSYSTEM_LAUNCHER: i32 = 1369;
const ATTR_RIG_SIZE: i32 = 1547;

const ATTR_CHARGE_GROUPS: [i32; 5] = [604, 605, 606, 609, 610];
const CAN_FIT_GROUP_ATTR_IDS: [i32; 20] = [
    1298, 1299, 1300, 1301, 1872, 1879, 1880, 1881, 2065, 2396, 2476, 2477, 2478, 2479, 2480, 2481,
    2482, 2483, 2484, 2485,
];
const CAN_FIT_TYPE_ATTR_IDS: [i32; 11] = [
    1302, 1303, 1304, 1305, 1944, 2103, 2463, 2486, 2487, 2488, 2758,
];

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValidationSlotType {
    High,
    Medium,
    Low,
    Rig,
    SubSystem,
    Service,
    TacticalMode,
    Implant,
    Booster,
    Drone,
    Fighter,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ValidationIssue {
    pub slot_type: ValidationSlotType,
    pub index: Option<i32>,
    pub kind: ValidationIssueKind,
}

#[derive(Debug, Clone, PartialEq)]
pub enum ValidationIssueKind {
    Error(ValidationErrorKey),
    Warning(ValidationWarningKey),
}

#[derive(Debug, Clone, PartialEq)]
pub enum ValidationErrorKey {
    IncompatibleChargeSize { expected: u8, actual: u8 },
    IncompatibleChargeCapacity { max: f64, actual: f64 },
    IncompatibleChargeGroup { expected: Vec<i32>, actual: i32 },
    TooMuchTurret { expected: u8, actual: u8 },
    TooMuchLauncher { expected: u8, actual: u8 },
    ConflictItem { group_id: i32 },
    DuplicateBooster { slot: i32 },
    IncompatibleShipGroup { expected: Vec<i32> },
    IncompatibleShipType { expected: Vec<i32> },
    IncompatibleRigSize { expected: u8, actual: u8 },
}

#[derive(Debug, Clone, PartialEq)]
pub enum ValidationWarningKey {
    MissingCharge,
}

struct ValidationContext<'a> {
    fit: &'a FitStorage,
    ship: &'a Ship,
    info: &'a dyn InfoProvider,
}

type ValidationRule = fn(&ValidationContext<'_>, &mut Vec<ValidationIssue>);

const VALIDATION_RULES: &[ValidationRule] = &[
    validate_slot_counts,
    validate_fit_targets,
    validate_rig_sizes,
    validate_booster_slots,
    validate_charges,
    validate_max_active_groups,
];

pub(crate) fn validate_fit(
    fit: &FitStorage,
    ship: &Ship,
    info: &impl InfoProvider,
) -> Vec<ValidationIssue> {
    let context = ValidationContext { fit, ship, info };
    let mut issues = Vec::new();
    for rule in VALIDATION_RULES {
        rule(&context, &mut issues);
    }
    issues
}

fn validate_slot_counts(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    let fit = context.fit.get_container();
    let (actual_turret, actual_launcher) = fit
        .fit
        .modules
        .iter()
        .filter(|module| matches!(module.slot.slot_type, ItemSlotType::High))
        .map(|module| {
            let type_id = module.item_id.as_type_id(fit);
            if context
                .info
                .get_dogma_effects(type_id)
                .iter()
                .any(|effect| effect.effect_id == EFFECT_TURRET)
            {
                (1, 0)
            } else if context
                .info
                .get_dogma_effects(type_id)
                .iter()
                .any(|effect| effect.effect_id == EFFECT_LAUNCHER)
            {
                (0, 1)
            } else {
                (0, 0)
            }
        })
        .fold(
            (0, 0),
            |(turret, launcher), (next_turret, next_launcher)| {
                (turret + next_turret, launcher + next_launcher)
            },
        );

    let ship_attributes = context.info.get_dogma_attributes(fit.fit.ship_type_id);
    let mut turret = find_attr(&ship_attributes, ATTR_TURRET).unwrap_or(0.0) as u8;
    let mut launcher = find_attr(&ship_attributes, ATTR_LAUNCHER).unwrap_or(0.0) as u8;

    for module in fit
        .fit
        .modules
        .iter()
        .filter(|module| matches!(module.slot.slot_type, ItemSlotType::SubSystem))
    {
        let type_id = module.item_id.as_type_id(fit);
        let attributes = context.info.get_dogma_attributes(type_id);
        turret += find_attr(&attributes, ATTR_SUBSYSTEM_TURRET).unwrap_or(0.0) as u8;
        launcher += find_attr(&attributes, ATTR_SUBSYSTEM_LAUNCHER).unwrap_or(0.0) as u8;
    }

    if actual_turret > turret {
        issues.push(ValidationIssue {
            slot_type: ValidationSlotType::High,
            index: None,
            kind: ValidationIssueKind::Error(ValidationErrorKey::TooMuchTurret {
                expected: turret,
                actual: actual_turret,
            }),
        });
    }
    if actual_launcher > launcher {
        issues.push(ValidationIssue {
            slot_type: ValidationSlotType::High,
            index: None,
            kind: ValidationIssueKind::Error(ValidationErrorKey::TooMuchLauncher {
                expected: launcher,
                actual: actual_launcher,
            }),
        });
    }
}

fn validate_fit_targets(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    let fit = context.fit.get_container();
    let ship_type = context.info.get_type(fit.fit.ship_type_id);

    for module in fit.fit.modules.iter() {
        let Some(slot_type) = validation_slot_type(module.slot.slot_type) else {
            continue;
        };
        let type_id = module.item_id.as_type_id(fit);
        let groups = context
            .info
            .get_dogma_attributes(type_id)
            .into_iter()
            .filter(|attr| CAN_FIT_GROUP_ATTR_IDS.contains(&attr.attribute_id))
            .map(|attr| attr.value as i32)
            .filter(|&group_id| group_id != 0)
            .collect::<Vec<_>>();
        let types = context
            .info
            .get_dogma_attributes(type_id)
            .into_iter()
            .filter(|attr| CAN_FIT_TYPE_ATTR_IDS.contains(&attr.attribute_id))
            .map(|attr| attr.value as i32)
            .filter(|&type_id| type_id != 0)
            .collect::<Vec<_>>();

        let group_matches = groups.contains(&ship_type.group_id);
        let type_matches = types.contains(&fit.fit.ship_type_id);
        if group_matches || type_matches || (groups.is_empty() && types.is_empty()) {
            continue;
        }

        if !groups.is_empty() {
            issues.push(ValidationIssue {
                slot_type,
                index: Some(module.slot.index),
                kind: ValidationIssueKind::Error(ValidationErrorKey::IncompatibleShipGroup {
                    expected: groups,
                }),
            });
        }
        if !types.is_empty() {
            issues.push(ValidationIssue {
                slot_type,
                index: Some(module.slot.index),
                kind: ValidationIssueKind::Error(ValidationErrorKey::IncompatibleShipType {
                    expected: types,
                }),
            });
        }
    }
}

fn validate_rig_sizes(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    let fit = context.fit.get_container();
    let ship_rig_size = context
        .info
        .get_dogma_attributes(fit.fit.ship_type_id)
        .iter()
        .find_map(|attr| (attr.attribute_id == ATTR_RIG_SIZE).then_some(attr.value as u8));

    for module in fit
        .fit
        .modules
        .iter()
        .filter(|module| matches!(module.slot.slot_type, ItemSlotType::Rig))
    {
        let rig_size = context
            .info
            .get_dogma_attributes(module.item_id.as_type_id(fit))
            .iter()
            .find_map(|attr| (attr.attribute_id == ATTR_RIG_SIZE).then_some(attr.value as u8));

        if let (Some(expected), Some(actual)) = (ship_rig_size, rig_size) {
            if expected != actual {
                issues.push(ValidationIssue {
                    slot_type: ValidationSlotType::Rig,
                    index: Some(module.slot.index),
                    kind: ValidationIssueKind::Error(ValidationErrorKey::IncompatibleRigSize {
                        expected,
                        actual,
                    }),
                });
            }
        }
    }
}

fn validate_booster_slots(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    let fit = context.fit.get_container();
    let mut slots: HashMap<i32, usize> = HashMap::new();
    for booster in &fit.fit.boosters {
        if let Some(slot) = booster_slot(booster.type_id, context.info) {
            *slots.entry(slot).or_default() += 1;
        }
    }

    for booster in &fit.fit.boosters {
        if let Some(slot) = booster_slot(booster.type_id, context.info) {
            if slots.get(&slot).is_some_and(|&count| count > 1) {
                issues.push(ValidationIssue {
                    slot_type: ValidationSlotType::Booster,
                    index: Some(booster.index),
                    kind: ValidationIssueKind::Error(ValidationErrorKey::DuplicateBooster { slot }),
                });
            }
        }
    }
}

fn validate_charges(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    for item in context
        .ship
        .modules
        .iter()
        .filter(|item| is_primary_module_slot(item))
    {
        let Some(slot_type) = output_validation_slot_type(item) else {
            continue;
        };
        let ammo_capacity = item_attribute(item, ATTR_AMMO_CAPACITY);
        if let Some(charge) = &item.charge {
            if let (Some(max), Some(actual)) = (ammo_capacity, item_attribute(charge, ATTR_VOLUME))
            {
                if actual > max {
                    issues.push(ValidationIssue {
                        slot_type,
                        index: item.slot.index,
                        kind: ValidationIssueKind::Error(
                            ValidationErrorKey::IncompatibleChargeCapacity { max, actual },
                        ),
                    });
                }
            }

            if let Some(expected) = item_attribute(item, ATTR_CHARGE_SIZE) {
                if let Some(actual) = item_attribute(charge, ATTR_CHARGE_SIZE) {
                    if expected as u8 != actual as u8 {
                        issues.push(ValidationIssue {
                            slot_type,
                            index: item.slot.index,
                            kind: ValidationIssueKind::Error(
                                ValidationErrorKey::IncompatibleChargeSize {
                                    expected: expected as u8,
                                    actual: actual as u8,
                                },
                            ),
                        });
                    }
                }
            }

            let expected_groups = item_accepted_charge_groups(item);
            if !expected_groups.is_empty() {
                if let Some(actual) = item_group_id(context, charge) {
                    if !expected_groups.contains(&actual) {
                        issues.push(ValidationIssue {
                            slot_type,
                            index: item.slot.index,
                            kind: ValidationIssueKind::Error(
                                ValidationErrorKey::IncompatibleChargeGroup {
                                    expected: expected_groups,
                                    actual,
                                },
                            ),
                        });
                    }
                }
            }
        } else if ammo_capacity.is_some() && item_accepts_charge(item) {
            issues.push(ValidationIssue {
                slot_type,
                index: item.slot.index,
                kind: ValidationIssueKind::Warning(ValidationWarningKey::MissingCharge),
            });
        }
    }
}

fn validate_max_active_groups(context: &ValidationContext<'_>, issues: &mut Vec<ValidationIssue>) {
    let mut groups: HashMap<i32, u8> = HashMap::new();
    for item in context
        .ship
        .modules
        .iter()
        .filter(|item| is_primary_module_slot(item) && item_is_active(item))
        .filter(|item| item_attribute(item, ATTR_MAX_ACTIVE).is_some_and(|value| value == 1.0))
    {
        if let Some(group_id) = item_group_id(context, item) {
            *groups.entry(group_id).or_default() += 1;
        }
    }
    groups.retain(|_, count| *count > 1);

    for item in context
        .ship
        .modules
        .iter()
        .filter(|item| is_primary_module_slot(item) && item_is_active(item))
        .filter(|item| item_attribute(item, ATTR_MAX_ACTIVE).is_some_and(|value| value == 1.0))
    {
        let Some(group_id) = item_group_id(context, item) else {
            continue;
        };
        if !groups.contains_key(&group_id) {
            continue;
        }
        let Some(slot_type) = output_validation_slot_type(item) else {
            continue;
        };
        issues.push(ValidationIssue {
            slot_type,
            index: item.slot.index,
            kind: ValidationIssueKind::Error(ValidationErrorKey::ConflictItem { group_id }),
        });
    }
}

fn validation_slot_type(slot_type: ItemSlotType) -> Option<ValidationSlotType> {
    match slot_type {
        ItemSlotType::High => Some(ValidationSlotType::High),
        ItemSlotType::Medium => Some(ValidationSlotType::Medium),
        ItemSlotType::Low => Some(ValidationSlotType::Low),
        ItemSlotType::Rig => Some(ValidationSlotType::Rig),
        ItemSlotType::SubSystem => Some(ValidationSlotType::SubSystem),
        ItemSlotType::Service => Some(ValidationSlotType::Service),
        ItemSlotType::TacticalMode => Some(ValidationSlotType::TacticalMode),
    }
}

fn output_validation_slot_type(item: &Item) -> Option<ValidationSlotType> {
    match item.slot.slot_type {
        crate::api::output::OutSlotType::High => Some(ValidationSlotType::High),
        crate::api::output::OutSlotType::Medium => Some(ValidationSlotType::Medium),
        crate::api::output::OutSlotType::Low => Some(ValidationSlotType::Low),
        crate::api::output::OutSlotType::Rig => Some(ValidationSlotType::Rig),
        crate::api::output::OutSlotType::SubSystem => Some(ValidationSlotType::SubSystem),
        crate::api::output::OutSlotType::Service => Some(ValidationSlotType::Service),
        crate::api::output::OutSlotType::TacticalMode => Some(ValidationSlotType::TacticalMode),
        crate::api::output::OutSlotType::DroneBay { .. } => Some(ValidationSlotType::Drone),
        crate::api::output::OutSlotType::Fighter { .. } => Some(ValidationSlotType::Fighter),
        crate::api::output::OutSlotType::Implant => Some(ValidationSlotType::Implant),
        crate::api::output::OutSlotType::Booster => Some(ValidationSlotType::Booster),
        crate::api::output::OutSlotType::Charge | crate::api::output::OutSlotType::Fake => None,
    }
}

fn is_primary_module_slot(item: &Item) -> bool {
    matches!(
        item.slot.slot_type,
        crate::api::output::OutSlotType::High
            | crate::api::output::OutSlotType::Medium
            | crate::api::output::OutSlotType::Low
    )
}

fn item_is_active(item: &Item) -> bool {
    matches!(
        item.state,
        crate::api::output::EffectCategory::Active | crate::api::output::EffectCategory::Overload
    )
}

fn item_group_id(context: &ValidationContext<'_>, item: &Item) -> Option<i32> {
    Some(
        context
            .info
            .get_type(resolve_output_item_type_id(context.fit, item.item_id)?)
            .group_id,
    )
}

fn resolve_output_item_type_id(fit: &FitStorage, item_id: ItemID) -> Option<i32> {
    match item_id {
        ItemID::Item(type_id) => Some(type_id),
        ItemID::Dynamic(dynamic_id) => fit.dynamic_item_base_type_id(dynamic_id),
    }
}

fn item_attribute(item: &Item, attribute_id: i32) -> Option<f64> {
    item.attributes
        .get(&attribute_id)
        .map(|attribute| attribute.value.unwrap_or(attribute.base_value))
}

fn item_accepts_charge(item: &Item) -> bool {
    !item_accepted_charge_groups(item).is_empty()
}

fn item_accepted_charge_groups(item: &Item) -> Vec<i32> {
    ATTR_CHARGE_GROUPS
        .iter()
        .filter_map(|attribute_id| item_attribute(item, *attribute_id).map(|value| value as i32))
        .filter(|&group_id| group_id != 0)
        .collect()
}

fn booster_slot(type_id: i32, info: &dyn InfoProvider) -> Option<i32> {
    info.get_dogma_attributes(type_id)
        .iter()
        .find_map(|attr| (attr.attribute_id == ATTR_BOOSTER_SLOT).then_some(attr.value as i32))
}

fn find_attr(attributes: &[eve_fit_os::fit::TypeDogmaAttribute], attribute_id: i32) -> Option<f64> {
    attributes
        .iter()
        .find_map(|attr| (attr.attribute_id == attribute_id).then_some(attr.value))
}
