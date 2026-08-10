use eve_fit_os::calculate::item::FighterAbility;
use eve_fit_os::fit::{
    FitContainer, ItemBooster, ItemCharge, ItemDrone, ItemFighter, ItemImplant, ItemModule,
    ItemSlot, ItemSlotType, ItemState,
};
use eve_fit_os::provider::InfoProvider;
use serde::{Deserialize, Serialize};

use super::FitToolError;

/// A single requested edit to the attached fit.
#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum FitEditOp {
    AddModule {
        slot_type: String,
        type_id: i32,
        #[serde(default)]
        state: Option<String>,
        #[serde(default)]
        charge_type_id: Option<i32>,
    },
    RemoveModule {
        slot_type: String,
        index: i32,
    },
    SetModuleCharge {
        slot_type: String,
        index: i32,
        #[serde(default)]
        charge_type_id: Option<i32>,
    },
    SetModuleState {
        slot_type: String,
        index: i32,
        state: String,
    },
    AddDrone {
        type_id: i32,
        /// `bay` (default) or `space`.
        #[serde(default)]
        state: Option<String>,
    },
    /// Removes every drone of the given type.
    RemoveDrone {
        type_id: i32,
    },
    /// Sets the state of every drone of the given type (`bay` or `space`).
    SetDroneState {
        type_id: i32,
        state: String,
    },
    AddFighter {
        type_id: i32,
        /// Ability bitmask (1 = attack turret, 2 = missiles, 4 = attack
        /// missile, 8 = bomb); defaults to 0 (no ability active).
        #[serde(default)]
        ability: Option<u8>,
    },
    /// Removes every fighter of the given type.
    RemoveFighter {
        type_id: i32,
    },
    /// Slots an implant, replacing any implant already in that slot.
    SetImplant {
        type_id: i32,
        slot: i32,
    },
    RemoveImplant {
        slot: i32,
    },
    /// Slots a booster, replacing any booster already in that slot.
    SetBooster {
        type_id: i32,
        slot: i32,
    },
    RemoveBooster {
        slot: i32,
    },
}

const MAX_IMPLANT_SLOT: i32 = 10;
const MAX_BOOSTER_SLOT: i32 = 3;

// Dogma attribute ids, mirroring `bootstrap/constant.py` — the app derives its
// storage layout (fixed slot lists, implant slot map) from the same
// attributes, so validating against them here keeps both sides in agreement.
const ATTR_IMPLANT_SLOT: i32 = 331;
const ATTR_HIGH_SLOTS: i32 = 14;
const ATTR_MEDIUM_SLOTS: i32 = 13;
const ATTR_LOW_SLOTS: i32 = 12;
const ATTR_RIG_SLOTS: i32 = 1137;
const ATTR_SUBSYSTEM_SLOTS: i32 = 1367;
const ATTR_SERVICE_SLOTS: i32 = 2056;
const ATTR_HIGH_SLOT_MODIFIER: i32 = 1374;
const ATTR_MEDIUM_SLOT_MODIFIER: i32 = 1375;
const ATTR_LOW_SLOT_MODIFIER: i32 = 1376;

/// The outcome of applying a batch of edits to a copy of the fit.
#[derive(Debug, Clone)]
pub struct FitEditResult {
    pub container: FitContainer,
    /// Human-readable description of each edit that was applied.
    pub applied: Vec<String>,
    /// The ops that were applied, in order; forwarded to the app for
    /// persistence so both sides apply exactly the same edits.
    pub applied_ops: Vec<FitEditOp>,
    /// Edits that could not be applied, with the reason.
    pub rejected: Vec<String>,
}

fn parse_slot_type(slot_type: &str) -> Result<ItemSlotType, FitToolError> {
    match slot_type.to_lowercase().as_str() {
        "high" => Ok(ItemSlotType::High),
        "medium" => Ok(ItemSlotType::Medium),
        "low" => Ok(ItemSlotType::Low),
        "rig" => Ok(ItemSlotType::Rig),
        "subsystem" => Ok(ItemSlotType::SubSystem),
        "service" => Ok(ItemSlotType::Service),
        "tactical_mode" => Ok(ItemSlotType::TacticalMode),
        _ => Err(FitToolError::UnknownSection(slot_type.to_string())),
    }
}

/// Module edits cannot target the tactical mode: the app stores it outside
/// the fixed module slot lists, so such an op would apply to the engine model
/// but be silently dropped when the app persists it.
fn parse_module_slot_type(slot_type: &str) -> Result<ItemSlotType, FitToolError> {
    let parsed = parse_slot_type(slot_type)?;
    if matches!(parsed, ItemSlotType::TacticalMode) {
        return Err(FitToolError::BadPayload(
            "the tactical mode cannot be edited with module ops".to_string(),
        ));
    }
    Ok(parsed)
}

fn parse_state(state: &str) -> Result<ItemState, FitToolError> {
    match state.to_lowercase().as_str() {
        "passive" => Ok(ItemState::Passive),
        "online" => Ok(ItemState::Online),
        "active" => Ok(ItemState::Active),
        "overload" => Ok(ItemState::Overload),
        _ => Err(FitToolError::BadPayload(format!("unknown state `{state}`"))),
    }
}

/// Drone states use `bay`/`space` rather than the module state names; the
/// engine maps them to `Passive` (in the drone bay) and `Active` (in space).
fn parse_drone_state(state: &str) -> Result<ItemState, FitToolError> {
    match state.to_lowercase().as_str() {
        "bay" => Ok(ItemState::Passive),
        "space" => Ok(ItemState::Active),
        _ => Err(FitToolError::BadPayload(format!(
            "unknown drone state `{state}`; expected `bay` or `space`"
        ))),
    }
}

/// Drones/fighters of the same type share a group; a new type starts a new
/// group one past the current maximum.
fn next_group_id(existing: impl Iterator<Item = (i32, u8)>, type_id: i32) -> u8 {
    let mut max_group = None;
    for (existing_type, group_id) in existing {
        if existing_type == type_id {
            return group_id;
        }
        max_group = Some(max_group.map_or(group_id, |max: u8| max.max(group_id)));
    }
    max_group.map(|max| max.saturating_add(1)).unwrap_or(0)
}

fn validate_slot(kind: &str, slot: i32, max: i32) -> Result<i32, FitToolError> {
    if (1..=max).contains(&slot) {
        Ok(slot)
    } else {
        Err(FitToolError::BadPayload(format!(
            "{kind} slot {slot} out of range; expected 1..={max}"
        )))
    }
}

fn slot_matches(module: &ItemModule, slot_type: ItemSlotType, index: i32) -> bool {
    module.slot.slot_type == slot_type && module.slot.index == index
}

/// A type's dogma attribute value, if the attribute is present on the type.
fn type_attr(info: &impl InfoProvider, type_id: i32, attribute_id: i32) -> Option<f64> {
    info.get_dogma_attributes(type_id)
        .iter()
        .find_map(|attr| (attr.attribute_id == attribute_id).then_some(attr.value))
}

/// The number of module slots of [slot_type] the ship currently provides,
/// mirroring the app's storage layout: while subsystems are fitted, the
/// high/medium/low counts come from the subsystems' slot-modifier attributes
/// (they redefine the slot topology); otherwise from the ship's own slot
/// attributes.
fn slot_capacity(
    container: &FitContainer,
    info: &impl InfoProvider,
    slot_type: ItemSlotType,
) -> i32 {
    let ship_attr = |attribute_id: i32| {
        type_attr(info, container.fit.ship_type_id, attribute_id).unwrap_or(0.0) as i32
    };
    match slot_type {
        ItemSlotType::High | ItemSlotType::Medium | ItemSlotType::Low => {
            let (base, modifier) = match slot_type {
                ItemSlotType::High => (ATTR_HIGH_SLOTS, ATTR_HIGH_SLOT_MODIFIER),
                ItemSlotType::Medium => (ATTR_MEDIUM_SLOTS, ATTR_MEDIUM_SLOT_MODIFIER),
                _ => (ATTR_LOW_SLOTS, ATTR_LOW_SLOT_MODIFIER),
            };
            let subsystems: Vec<i32> = container
                .fit
                .modules
                .iter()
                .filter(|module| matches!(module.slot.slot_type, ItemSlotType::SubSystem))
                .map(|module| module.item_id.as_type_id(container))
                .collect();
            if subsystems.is_empty() {
                ship_attr(base)
            } else {
                subsystems
                    .iter()
                    .map(|type_id| type_attr(info, *type_id, modifier).unwrap_or(0.0) as i32)
                    .sum()
            }
        }
        ItemSlotType::Rig => ship_attr(ATTR_RIG_SLOTS),
        ItemSlotType::SubSystem => ship_attr(ATTR_SUBSYSTEM_SLOTS),
        ItemSlotType::Service => ship_attr(ATTR_SERVICE_SLOTS),
        ItemSlotType::TacticalMode => 0,
    }
}

/// The first slot index within [slot_type] not occupied in [container]
/// (smallest non-negative free index, matching the app's fixed-slot layout,
/// which can have gaps after removals).
fn next_index_for(container: &FitContainer, slot_type: ItemSlotType) -> i32 {
    let occupied: std::collections::HashSet<i32> = container
        .fit
        .modules
        .iter()
        .filter(|module| module.slot.slot_type == slot_type)
        .map(|module| module.slot.index)
        .collect();
    (0..).find(|index| !occupied.contains(index)).unwrap_or(0)
}

/// Apply [ops] to a clone of [container], returning the edited container plus
/// per-edit outcomes. Never mutates [container]. [info] provides the dogma
/// attributes needed to reject ops the app could not persist (implant slot
/// mismatches, modules past the ship's slot capacity), so the reported
/// `applied` ops describe what the app will actually store.
pub fn apply_edit_ops(
    container: &FitContainer,
    ops: &[FitEditOp],
    info: &impl InfoProvider,
) -> FitEditResult {
    let mut edited = container.clone();
    let mut applied = Vec::new();
    let mut applied_ops = Vec::new();
    let mut rejected = Vec::new();

    for op in ops {
        match op {
            FitEditOp::AddModule {
                slot_type,
                type_id,
                state,
                charge_type_id,
            } => {
                let result = (|| -> Result<ItemModule, FitToolError> {
                    let parsed_slot = parse_module_slot_type(slot_type)?;
                    let state = match state {
                        Some(state) => parse_state(state)?,
                        None => ItemState::Active,
                    };
                    let index = next_index_for(&edited, parsed_slot);
                    let capacity = slot_capacity(&edited, info, parsed_slot);
                    if index >= capacity {
                        return Err(FitToolError::BadPayload(format!(
                            "no free {slot_type} slots on this ship ({capacity} total)"
                        )));
                    }
                    Ok(ItemModule {
                        item_id: eve_fit_os::calculate::item::ItemID::Item(*type_id),
                        slot: ItemSlot {
                            slot_type: parsed_slot,
                            index,
                        },
                        state,
                        charge: charge_type_id.map(|type_id| ItemCharge { type_id }),
                    })
                })();
                match result {
                    Ok(module) => {
                        let description = format!(
                            "add module {type_id} to {slot_type} slot {} ({:?})",
                            module.slot.index, module.state
                        );
                        edited.fit.modules.push(module);
                        applied.push(description);
                        applied_ops.push(op.clone());
                    }
                    Err(e) => rejected.push(format!("add_module {type_id}: {e}")),
                }
            }

            FitEditOp::RemoveModule { slot_type, index } => {
                let result = parse_module_slot_type(slot_type).map(|parsed| (parsed, *index));
                match result {
                    Ok((parsed_slot, index)) => {
                        let before = edited.fit.modules.len();
                        edited
                            .fit
                            .modules
                            .retain(|module| !slot_matches(module, parsed_slot, index));
                        if edited.fit.modules.len() < before {
                            applied.push(format!("remove module at {slot_type} slot {index}"));
                            applied_ops.push(op.clone());
                        } else {
                            rejected.push(format!(
                                "remove_module: no module at {slot_type} slot {index}"
                            ));
                        }
                    }
                    Err(e) => rejected.push(format!("remove_module: {e}")),
                }
            }

            FitEditOp::SetModuleCharge {
                slot_type,
                index,
                charge_type_id,
            } => {
                let result = parse_module_slot_type(slot_type).map(|parsed| (parsed, *index));
                match result {
                    Ok((parsed_slot, index)) => {
                        let module = edited
                            .fit
                            .modules
                            .iter_mut()
                            .find(|module| slot_matches(module, parsed_slot, index));
                        match module {
                            Some(module) => {
                                module.charge =
                                    charge_type_id.map(|type_id| ItemCharge { type_id });
                                applied.push(format!(
                                    "set charge on {slot_type} slot {index} to {charge_type_id:?}"
                                ));
                                applied_ops.push(op.clone());
                            }
                            None => rejected.push(format!(
                                "set_module_charge: no module at {slot_type} slot {index}"
                            )),
                        }
                    }
                    Err(e) => rejected.push(format!("set_module_charge: {e}")),
                }
            }

            FitEditOp::SetModuleState {
                slot_type,
                index,
                state,
            } => {
                let result = (|| -> Result<(ItemSlotType, i32, ItemState), FitToolError> {
                    Ok((
                        parse_module_slot_type(slot_type)?,
                        *index,
                        parse_state(state)?,
                    ))
                })();
                match result {
                    Ok((parsed_slot, index, parsed_state)) => {
                        let module = edited
                            .fit
                            .modules
                            .iter_mut()
                            .find(|module| slot_matches(module, parsed_slot, index));
                        match module {
                            Some(module) => {
                                module.state = parsed_state;
                                applied.push(format!(
                                    "set state of {slot_type} slot {index} to {state}"
                                ));
                                applied_ops.push(op.clone());
                            }
                            None => rejected.push(format!(
                                "set_module_state: no module at {slot_type} slot {index}"
                            )),
                        }
                    }
                    Err(e) => rejected.push(format!("set_module_state: {e}")),
                }
            }

            FitEditOp::AddDrone { type_id, state } => {
                let result = match state {
                    Some(state) => parse_drone_state(state),
                    None => Ok(ItemState::Passive),
                };
                match result {
                    Ok(state) => {
                        let group_id = next_group_id(
                            edited
                                .fit
                                .drones
                                .iter()
                                .map(|drone| (drone.type_id, drone.group_id)),
                            *type_id,
                        );
                        edited.fit.drones.push(ItemDrone {
                            type_id: *type_id,
                            group_id,
                            state,
                        });
                        let location = if state == ItemState::Passive {
                            "bay"
                        } else {
                            "space"
                        };
                        applied.push(format!("add drone {type_id} ({location})"));
                        applied_ops.push(op.clone());
                    }
                    Err(e) => rejected.push(format!("add_drone {type_id}: {e}")),
                }
            }

            FitEditOp::RemoveDrone { type_id } => {
                let before = edited.fit.drones.len();
                edited.fit.drones.retain(|drone| drone.type_id != *type_id);
                let removed = before - edited.fit.drones.len();
                if removed > 0 {
                    applied.push(format!("remove {removed} drone(s) of type {type_id}"));
                    applied_ops.push(op.clone());
                } else {
                    rejected.push(format!("remove_drone: no drone of type {type_id}"));
                }
            }

            FitEditOp::SetDroneState { type_id, state } => match parse_drone_state(state) {
                Ok(state) => {
                    let mut matched = 0;
                    for drone in edited
                        .fit
                        .drones
                        .iter_mut()
                        .filter(|drone| drone.type_id == *type_id)
                    {
                        drone.state = state;
                        matched += 1;
                    }
                    if matched > 0 {
                        let location = if state == ItemState::Passive {
                            "bay"
                        } else {
                            "space"
                        };
                        applied.push(format!(
                            "set state of {matched} drone(s) of type {type_id} to {location}"
                        ));
                        applied_ops.push(op.clone());
                    } else {
                        rejected.push(format!("set_drone_state: no drone of type {type_id}"));
                    }
                }
                Err(e) => rejected.push(format!("set_drone_state {type_id}: {e}")),
            },

            FitEditOp::AddFighter { type_id, ability } => {
                let bits = ability.unwrap_or(0);
                match FighterAbility::from_bits(bits) {
                    Some(ability) => {
                        let group_id = next_group_id(
                            edited
                                .fit
                                .fighters
                                .iter()
                                .map(|fighter| (fighter.type_id, fighter.group_id)),
                            *type_id,
                        );
                        edited.fit.fighters.push(ItemFighter {
                            type_id: *type_id,
                            group_id,
                            ability,
                        });
                        applied.push(format!(
                            "add fighter {type_id} (ability {})",
                            ability.bits()
                        ));
                        applied_ops.push(op.clone());
                    }
                    None => rejected.push(format!(
                        "add_fighter {type_id}: unsupported ability bits {bits:#06b} (only 0..=0b1111 are defined)"
                    )),
                }
            }

            FitEditOp::RemoveFighter { type_id } => {
                let before = edited.fit.fighters.len();
                edited
                    .fit
                    .fighters
                    .retain(|fighter| fighter.type_id != *type_id);
                let removed = before - edited.fit.fighters.len();
                if removed > 0 {
                    applied.push(format!("remove {removed} fighter(s) of type {type_id}"));
                    applied_ops.push(op.clone());
                } else {
                    rejected.push(format!("remove_fighter: no fighter of type {type_id}"));
                }
            }

            FitEditOp::SetImplant { type_id, slot } => {
                let result = (|| -> Result<i32, FitToolError> {
                    let slot = validate_slot("implant", *slot, MAX_IMPLANT_SLOT)?;
                    // The app keys implants by the type's implant-slot
                    // attribute; slotting a type into a foreign slot would be
                    // silently dropped on persistence.
                    match type_attr(info, *type_id, ATTR_IMPLANT_SLOT) {
                        None => Err(FitToolError::BadPayload(format!(
                            "type {type_id} is not an implant"
                        ))),
                        Some(actual) if actual as i32 != slot => {
                            Err(FitToolError::BadPayload(format!(
                                "implant {type_id} occupies slot {}, not slot {slot}",
                                actual as i32
                            )))
                        }
                        _ => Ok(slot),
                    }
                })();
                match result {
                    Ok(slot) => {
                        edited.fit.implants.retain(|implant| implant.index != slot);
                        edited.fit.implants.push(ItemImplant {
                            type_id: *type_id,
                            index: slot,
                        });
                        applied.push(format!("set implant slot {slot} to {type_id}"));
                        applied_ops.push(op.clone());
                    }
                    Err(e) => rejected.push(format!("set_implant {type_id}: {e}")),
                }
            }

            FitEditOp::RemoveImplant { slot } => {
                let before = edited.fit.implants.len();
                edited.fit.implants.retain(|implant| implant.index != *slot);
                if edited.fit.implants.len() < before {
                    applied.push(format!("remove implant at slot {slot}"));
                    applied_ops.push(op.clone());
                } else {
                    rejected.push(format!("remove_implant: no implant at slot {slot}"));
                }
            }

            FitEditOp::SetBooster { type_id, slot } => {
                match validate_slot("booster", *slot, MAX_BOOSTER_SLOT) {
                    Ok(slot) => {
                        edited.fit.boosters.retain(|booster| booster.index != slot);
                        edited.fit.boosters.push(ItemBooster {
                            type_id: *type_id,
                            index: slot,
                        });
                        applied.push(format!("set booster slot {slot} to {type_id}"));
                        applied_ops.push(op.clone());
                    }
                    Err(e) => rejected.push(format!("set_booster {type_id}: {e}")),
                }
            }

            FitEditOp::RemoveBooster { slot } => {
                let before = edited.fit.boosters.len();
                edited.fit.boosters.retain(|booster| booster.index != *slot);
                if edited.fit.boosters.len() < before {
                    applied.push(format!("remove booster at slot {slot}"));
                    applied_ops.push(op.clone());
                } else {
                    rejected.push(format!("remove_booster: no booster at slot {slot}"));
                }
            }
        }
    }

    FitEditResult {
        container: edited,
        applied,
        applied_ops,
        rejected,
    }
}
