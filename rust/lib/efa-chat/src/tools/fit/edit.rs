use eve_fit_os::fit::{FitContainer, ItemCharge, ItemModule, ItemSlot, ItemSlotType, ItemState};
use serde::Deserialize;

use super::FitToolError;

/// A single requested edit to the attached fit. Edits are applied to a copy
/// of the fit for what-if analysis; the user's real fit is never mutated.
#[derive(Debug, Clone, Deserialize)]
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
}

/// The outcome of applying a batch of edits to a copy of the fit.
#[derive(Debug, Clone)]
pub struct FitEditResult {
    pub container: FitContainer,
    /// Human-readable description of each edit that was applied.
    pub applied: Vec<String>,
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

fn parse_state(state: &str) -> Result<ItemState, FitToolError> {
    match state.to_lowercase().as_str() {
        "passive" => Ok(ItemState::Passive),
        "online" => Ok(ItemState::Online),
        "active" => Ok(ItemState::Active),
        "overload" => Ok(ItemState::Overload),
        _ => Err(FitToolError::BadPayload(format!("unknown state `{state}`"))),
    }
}

fn slot_matches(module: &ItemModule, slot_type: ItemSlotType, index: i32) -> bool {
    module.slot.slot_type == slot_type && module.slot.index == index
}

fn next_index_for(container: &FitContainer, slot_type: ItemSlotType) -> i32 {
    container
        .fit
        .modules
        .iter()
        .filter(|module| module.slot.slot_type == slot_type)
        .map(|module| module.slot.index)
        .max()
        .map(|index| index + 1)
        .unwrap_or(0)
}

/// Apply [ops] to a clone of [container], returning the edited container plus
/// per-edit outcomes. Never mutates [container].
pub fn apply_edit_ops(container: &FitContainer, ops: &[FitEditOp]) -> FitEditResult {
    let mut edited = container.clone();
    let mut applied = Vec::new();
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
                    let slot_type = parse_slot_type(slot_type)?;
                    let state = match state {
                        Some(state) => parse_state(state)?,
                        None => ItemState::Active,
                    };
                    let index = next_index_for(&edited, slot_type);
                    Ok(ItemModule {
                        item_id: eve_fit_os::calculate::item::ItemID::Item(*type_id),
                        slot: ItemSlot { slot_type, index },
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
                    }
                    Err(e) => rejected.push(format!("add_module {type_id}: {e}")),
                }
            }

            FitEditOp::RemoveModule { slot_type, index } => {
                let result = parse_slot_type(slot_type).map(|parsed| (parsed, *index));
                match result {
                    Ok((parsed_slot, index)) => {
                        let before = edited.fit.modules.len();
                        edited
                            .fit
                            .modules
                            .retain(|module| !slot_matches(module, parsed_slot, index));
                        if edited.fit.modules.len() < before {
                            applied.push(format!("remove module at {slot_type} slot {index}"));
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
                let result = parse_slot_type(slot_type).map(|parsed| (parsed, *index));
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
                    Ok((parse_slot_type(slot_type)?, *index, parse_state(state)?))
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
                            }
                            None => rejected.push(format!(
                                "set_module_state: no module at {slot_type} slot {index}"
                            )),
                        }
                    }
                    Err(e) => rejected.push(format!("set_module_state: {e}")),
                }
            }
        }
    }

    FitEditResult {
        container: edited,
        applied,
        rejected,
    }
}
