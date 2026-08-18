use std::collections::{HashMap, HashSet};

use eve_fit_os::calculate::Ship;
use eve_fit_os::calculate::item::{FighterAbility, ItemID};
use eve_fit_os::fit as ef;
use eve_fit_os::validate::{ValidationIssue, ValidationIssueKind, validate_fit};
use serde_json::{Value, json};

use crate::error::ApiError;
use crate::proto::fit as pb;
use crate::provider::FitDataProvider;

fn is_valid_state(value: i32) -> bool {
    pb::slots::SlotState::is_valid(value)
}

fn rack_capacity(layout: &pb::SnapshotShipLayout, slot_type: i32) -> Option<u32> {
    let capacity = match pb::SlotType::try_from(slot_type) {
        Ok(pb::SlotType::High) => layout.high_slots,
        Ok(pb::SlotType::Medium) => layout.medium_slots,
        Ok(pb::SlotType::Low) => layout.low_slots,
        Ok(pb::SlotType::Rig) => layout.rig_slots,
        Ok(pb::SlotType::Subsystem) => layout.subsystem_slots,
        Ok(pb::SlotType::Service) => layout.service_slots,
        Err(_) => return None,
    };
    Some(capacity)
}

/// Structural validation of the upload (spec §6.2 step 2): 400 on failure.
pub fn validate_structure(request: &pb::FitUploadRequest) -> Result<(), ApiError> {
    if request.fit_name.is_empty() {
        return Err(ApiError::bad_request("fit_name must not be empty"));
    }
    let state = &request.fit;
    let layout = &state.layout;

    let dynamic_ids: HashSet<u32> = state.dynamic_items.iter().map(|d| d.dynamic_id).collect();

    // A (slot_type, index) pair may be occupied by at most one module.
    // Duplicates would also make the canonical hash order-dependent, since
    // canonical_state's sort_by_key is stable on equal keys.
    let mut occupied_slots: HashSet<(i32, u32)> = HashSet::new();

    for module in &state.modules {
        let capacity = rack_capacity(layout, module.slot_type)
            .ok_or_else(|| ApiError::bad_request("invalid module slot_type"))?;
        if module.index >= capacity {
            return Err(ApiError::bad_request(format!(
                "module slot index {} out of bounds for slot_type {}",
                module.index, module.slot_type
            )));
        }
        if !occupied_slots.insert((module.slot_type, module.index)) {
            return Err(ApiError::bad_request(format!(
                "duplicate module at slot_type {} index {}",
                module.slot_type, module.index
            )));
        }
        if !is_valid_state(module.state) {
            return Err(ApiError::bad_request("invalid module slot state"));
        }
        match &module.item {
            Some(pb::fit_module::Item::TypeId(_)) => {}
            Some(pb::fit_module::Item::DynamicId(dynamic_id)) => {
                if !dynamic_ids.contains(dynamic_id) {
                    return Err(ApiError::bad_request(format!(
                        "dangling dynamic_id reference: {dynamic_id}"
                    )));
                }
            }
            None => return Err(ApiError::bad_request("module without an item")),
        }
        if module.slot_type == pb::SlotType::Subsystem as i32 && module.subsystem_type.is_none() {
            return Err(ApiError::bad_request(
                "SUBSYSTEM slot without subsystem_type",
            ));
        }
    }

    for mode in &state.available_tactical_modes {
        if !pb::tactical_mode::TacticalModeVariant::is_valid(mode.variant) {
            return Err(ApiError::bad_request("invalid tactical mode variant"));
        }
    }
    if let Some(selected) = state.tactical_mode_type_id {
        if !state
            .available_tactical_modes
            .iter()
            .any(|mode| mode.type_id == selected)
        {
            return Err(ApiError::bad_request(
                "tactical_mode_type_id not in available_tactical_modes",
            ));
        }
    }

    for drone in &state.drones {
        if !is_valid_state(drone.state) {
            return Err(ApiError::bad_request("invalid drone slot state"));
        }
    }
    for fighter in &state.fighters {
        if !pb::snapshot_fighter::SquadronGroup::is_valid(fighter.group) {
            return Err(ApiError::bad_request("invalid fighter squadron group"));
        }
        for ability in &fighter.abilities {
            if !pb::snapshot_fighter::Ability::is_valid(*ability) {
                return Err(ApiError::bad_request("invalid fighter ability"));
            }
        }
    }
    for implant in &state.implants {
        if !(1..=10).contains(&implant.slot_index) {
            return Err(ApiError::bad_request(format!(
                "implant slot_index {} not in 1..=10",
                implant.slot_index
            )));
        }
        if !is_valid_state(implant.state) {
            return Err(ApiError::bad_request("invalid implant slot state"));
        }
    }
    for booster in &state.boosters {
        if !is_valid_state(booster.state) {
            return Err(ApiError::bad_request("invalid booster slot state"));
        }
    }
    for skill in &state.skills {
        if skill.level > 5 {
            return Err(ApiError::bad_request(format!(
                "skill level {} exceeds 5",
                skill.level
            )));
        }
    }

    Ok(())
}

fn item_state(value: i32) -> ef::ItemState {
    match pb::slots::SlotState::try_from(value) {
        Ok(pb::slots::SlotState::Passive) => ef::ItemState::Passive,
        Ok(pb::slots::SlotState::Online) => ef::ItemState::Online,
        Ok(pb::slots::SlotState::Active) => ef::ItemState::Active,
        Ok(pb::slots::SlotState::Overload) => ef::ItemState::Overload,
        Err(_) => ef::ItemState::Passive,
    }
}

fn fighter_ability(abilities: &[i32]) -> FighterAbility {
    let mut flags = FighterAbility::empty();
    for ability in abilities {
        match pb::snapshot_fighter::Ability::try_from(*ability) {
            Ok(pb::snapshot_fighter::Ability::Turret) => flags |= FighterAbility::ATTACK_TURRET,
            Ok(pb::snapshot_fighter::Ability::Missiles) => flags |= FighterAbility::MISSILES,
            Ok(pb::snapshot_fighter::Ability::AttackMissiles) => {
                flags |= FighterAbility::ATTACK_MISSILE
            }
            Ok(pb::snapshot_fighter::Ability::Bomb) => flags |= FighterAbility::BOMB,
            Err(_) => {}
        }
    }
    flags
}

/// `FitState` → `FitContainer`, mirroring
/// `lib/storage/fit/schema.dart::convertToNative` (spec §12).
pub fn build_container(state: &pb::FitState) -> ef::FitContainer {
    let mut modules = Vec::new();
    for module in &state.modules {
        let slot_type = match pb::SlotType::try_from(module.slot_type) {
            Ok(pb::SlotType::High) => ef::ItemSlotType::High,
            Ok(pb::SlotType::Medium) => ef::ItemSlotType::Medium,
            Ok(pb::SlotType::Low) => ef::ItemSlotType::Low,
            Ok(pb::SlotType::Rig) => ef::ItemSlotType::Rig,
            Ok(pb::SlotType::Subsystem) => ef::ItemSlotType::SubSystem,
            Ok(pb::SlotType::Service) => ef::ItemSlotType::Service,
            Err(_) => continue,
        };
        // PASSIVE rigs are skipped (app convention).
        if slot_type == ef::ItemSlotType::Rig
            && module.state == pb::slots::SlotState::Passive as i32
        {
            continue;
        }
        // Subsystem slots are always fed to the engine as online (app
        // convention, schema.dart::convertModulesToNative).
        let state = if slot_type == ef::ItemSlotType::SubSystem {
            ef::ItemState::Online
        } else {
            item_state(module.state)
        };
        let item_id = match &module.item {
            Some(pb::fit_module::Item::TypeId(type_id)) => ItemID::Item(*type_id as i32),
            Some(pb::fit_module::Item::DynamicId(dynamic_id)) => {
                ItemID::Dynamic(*dynamic_id as i32)
            }
            None => continue,
        };
        modules.push(ef::ItemModule {
            item_id,
            slot: ef::ItemSlot {
                slot_type,
                index: module.index as i32,
            },
            state,
            charge: module.charge_type_id.map(|type_id| ef::ItemCharge {
                type_id: type_id as i32,
            }),
        });
    }
    // Selected tactical mode → synthetic module (app convention).
    if let Some(mode) = state.tactical_mode_type_id {
        modules.push(ef::ItemModule {
            item_id: ItemID::Item(mode as i32),
            slot: ef::ItemSlot {
                slot_type: ef::ItemSlotType::TacticalMode,
                index: 0,
            },
            state: ef::ItemState::Online,
            charge: None,
        });
    }

    let mut drones = Vec::new();
    for (index, drone) in state.drones.iter().enumerate() {
        for _ in 0..drone.quantity {
            drones.push(ef::ItemDrone {
                type_id: drone.type_id as i32,
                group_id: index as u8,
                state: item_state(drone.state),
            });
        }
    }

    let mut fighters = Vec::new();
    for (index, fighter) in state.fighters.iter().enumerate() {
        let ability = fighter_ability(&fighter.abilities);
        for _ in 0..fighter.quantity {
            fighters.push(ef::ItemFighter {
                type_id: fighter.type_id as i32,
                group_id: index as u8,
                ability,
            });
        }
    }

    // PASSIVE implants/boosters are skipped (app convention).
    let mut implants = Vec::new();
    for implant in &state.implants {
        if implant.state == pb::slots::SlotState::Passive as i32 {
            continue;
        }
        if let Some(type_id) = implant.type_id {
            implants.push(ef::ItemImplant {
                type_id: type_id as i32,
                index: implant.slot_index as i32,
            });
        }
    }
    let mut boosters = Vec::new();
    for booster in &state.boosters {
        if booster.state == pb::slots::SlotState::Passive as i32 {
            continue;
        }
        boosters.push(ef::ItemBooster {
            type_id: booster.type_id as i32,
            index: booster.slot_index as i32,
        });
    }

    let skills: HashMap<i32, u8> = state
        .skills
        .iter()
        .map(|skill| (skill.type_id as i32, skill.level as u8))
        .collect();

    // Only dynamic IDs actually referenced by modules, intersected with the
    // submitted dynamic items (app convention).
    let referenced: HashSet<i32> = state
        .modules
        .iter()
        .filter_map(|module| match &module.item {
            Some(pb::fit_module::Item::DynamicId(dynamic_id)) => Some(*dynamic_id as i32),
            _ => None,
        })
        .collect();
    let dynamic: HashMap<i32, ef::DynamicItem> = state
        .dynamic_items
        .iter()
        .filter(|item| referenced.contains(&(item.dynamic_id as i32)))
        .map(|item| {
            (
                item.dynamic_id as i32,
                ef::DynamicItem {
                    base_type: item.base_type_id as i32,
                    dynamic_attributes: item
                        .attributes
                        .iter()
                        .map(|a| (a.attribute_id, a.value))
                        .collect(),
                },
            )
        })
        .collect();

    let damage_profile = eve_fit_os::calculate::DamageProfile {
        em: state.damage_profile.em,
        explosive: state.damage_profile.explosive,
        kinetic: state.damage_profile.kinetic,
        thermal: state.damage_profile.thermal,
    };

    ef::FitContainer::new(
        ef::ItemFit {
            ship_type_id: state.ship_type_id as i32,
            damage_profile,
            modules,
            drones,
            fighters,
            implants,
            boosters,
        },
        skills,
        dynamic,
    )
}

fn issue_json(issue: &ValidationIssue) -> Value {
    let (severity, kind) = match &issue.kind {
        ValidationIssueKind::Error(key) => ("error", format!("{key:?}")),
        ValidationIssueKind::Warning(key) => ("warning", format!("{key:?}")),
    };
    json!({
        "slot_type": format!("{:?}", issue.slot_type),
        "index": issue.index,
        "severity": severity,
        "kind": kind,
    })
}

/// Run the engine, then validate (spec §6.2 steps 6b–6c). Error-level issues
/// → 422 `validation_failed` with the serialized issue list; warnings do not
/// block storage.
pub fn calculate_and_validate(
    container: &ef::FitContainer,
    provider: &FitDataProvider,
) -> Result<(Ship, Vec<Value>), ApiError> {
    let ship = eve_fit_os::calculate::calculate(container, provider);
    let issues = validate_fit(container, &ship, provider);

    let mut errors = Vec::new();
    let mut warnings = Vec::new();
    for issue in &issues {
        match &issue.kind {
            ValidationIssueKind::Error(_) => errors.push(issue_json(issue)),
            ValidationIssueKind::Warning(_) => warnings.push(issue_json(issue)),
        }
    }
    if !errors.is_empty() {
        return Err(ApiError::validation_failed(Value::Array(errors)));
    }
    Ok((ship, warnings))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::fit::fit_module;

    fn layout() -> pb::SnapshotShipLayout {
        pb::SnapshotShipLayout {
            high_slots: 2,
            medium_slots: 2,
            low_slots: 2,
            rig_slots: 2,
            subsystem_slots: 1,
            service_slots: 0,
            turret_hardpoints: 2,
            launcher_hardpoints: 0,
            fighter_tubes: 0,
        }
    }

    fn request(state: pb::FitState) -> pb::FitUploadRequest {
        pb::FitUploadRequest {
            server_id: "tranquility".to_string(),
            snapshot_hash: "abc".to_string(),
            fit_name: "test fit".to_string(),
            description: None,
            last_modified_ms: 1,
            generator: None,
            fit: state,
        }
    }

    fn state() -> pb::FitState {
        pb::FitState {
            ship_type_id: 100,
            layout: layout(),
            damage_profile: pb::DamageProfile {
                em: 0.25,
                thermal: 0.25,
                kinetic: 0.25,
                explosive: 0.25,
            },
            ..Default::default()
        }
    }

    #[test]
    fn rejects_empty_fit_name() {
        let mut request = request(state());
        request.fit_name = String::new();
        let err = validate_structure(&request).unwrap_err();
        assert_eq!(err.status, 400);
    }

    #[test]
    fn rejects_out_of_bounds_module_index() {
        let mut state = state();
        state.modules.push(pb::FitModule {
            item: Some(fit_module::Item::TypeId(1)),
            slot_type: pb::SlotType::High as i32,
            index: 2,
            state: pb::slots::SlotState::Active as i32,
            charge_type_id: None,
            subsystem_type: None,
        });
        assert!(validate_structure(&request(state)).is_err());
    }

    #[test]
    fn rejects_duplicate_module_slot() {
        let module = |index| pb::FitModule {
            item: Some(fit_module::Item::TypeId(1)),
            slot_type: pb::SlotType::High as i32,
            index,
            state: pb::slots::SlotState::Active as i32,
            charge_type_id: None,
            subsystem_type: None,
        };
        let mut dup = state();
        dup.modules = vec![module(0), module(0)];
        assert!(validate_structure(&request(dup)).is_err());

        let mut distinct = state();
        distinct.modules = vec![module(0), module(1)];
        assert!(validate_structure(&request(distinct)).is_ok());
    }

    #[test]
    fn rejects_subsystem_without_type() {
        let mut without_type = state();
        without_type.modules.push(pb::FitModule {
            item: Some(fit_module::Item::TypeId(1)),
            slot_type: pb::SlotType::Subsystem as i32,
            index: 0,
            state: pb::slots::SlotState::Online as i32,
            charge_type_id: None,
            subsystem_type: None,
        });
        assert!(validate_structure(&request(without_type)).is_err());

        let mut state_with_type = state();
        state_with_type.modules.push(pb::FitModule {
            item: Some(fit_module::Item::TypeId(1)),
            slot_type: pb::SlotType::Subsystem as i32,
            index: 0,
            state: pb::slots::SlotState::Online as i32,
            charge_type_id: None,
            subsystem_type: Some(pb::subsystem::SubsystemType::Core as i32),
        });
        assert!(validate_structure(&request(state_with_type)).is_ok());
    }

    #[test]
    fn rejects_dangling_dynamic_id() {
        let mut state = state();
        state.modules.push(pb::FitModule {
            item: Some(fit_module::Item::DynamicId(9)),
            slot_type: pb::SlotType::Low as i32,
            index: 0,
            state: pb::slots::SlotState::Online as i32,
            charge_type_id: None,
            subsystem_type: None,
        });
        assert!(validate_structure(&request(state)).is_err());
    }

    #[test]
    fn rejects_implant_slot_out_of_range() {
        let mut state = state();
        state.implants.push(pb::FitImplant {
            slot_index: 11,
            type_id: Some(1),
            state: pb::slots::SlotState::Active as i32,
        });
        assert!(validate_structure(&request(state)).is_err());
    }

    #[test]
    fn rejects_skill_level_above_5() {
        let mut state = state();
        state.skills.push(pb::FitSkill {
            type_id: 1,
            level: 6,
        });
        assert!(validate_structure(&request(state)).is_err());
    }

    #[test]
    fn rejects_unknown_tactical_mode_selection() {
        let mut without_mode = state();
        without_mode.tactical_mode_type_id = Some(42);
        assert!(validate_structure(&request(without_mode)).is_err());

        let mut with_mode = state();
        with_mode
            .available_tactical_modes
            .push(pb::FitTacticalModeRef {
                type_id: 42,
                variant: pb::tactical_mode::TacticalModeVariant::Defense as i32,
            });
        with_mode.tactical_mode_type_id = Some(42);
        assert!(validate_structure(&request(with_mode)).is_ok());
    }

    #[test]
    fn container_skips_passive_rigs_and_expands_groups() {
        let mut state = state();
        state.modules = vec![
            pb::FitModule {
                item: Some(fit_module::Item::TypeId(1)),
                slot_type: pb::SlotType::Rig as i32,
                index: 0,
                state: pb::slots::SlotState::Passive as i32,
                charge_type_id: None,
                subsystem_type: None,
            },
            pb::FitModule {
                item: Some(fit_module::Item::TypeId(2)),
                slot_type: pb::SlotType::Rig as i32,
                index: 1,
                state: pb::slots::SlotState::Online as i32,
                charge_type_id: None,
                subsystem_type: None,
            },
        ];
        state.drones = vec![pb::FitDrone {
            type_id: 5,
            state: pb::slots::SlotState::Active as i32,
            quantity: 3,
        }];
        state.fighters = vec![pb::FitFighter {
            type_id: 6,
            quantity: 2,
            max_squadron_size: 4,
            group: pb::snapshot_fighter::SquadronGroup::Light as i32,
            abilities: vec![
                pb::snapshot_fighter::Ability::Turret as i32,
                pb::snapshot_fighter::Ability::AttackMissiles as i32,
            ],
        }];
        state.tactical_mode_type_id = None;

        let container = build_container(&state);
        // Only the online rig survives.
        assert_eq!(container.fit.modules.len(), 1);
        assert_eq!(
            container.fit.modules[0].slot.slot_type,
            ef::ItemSlotType::Rig
        );
        assert_eq!(container.fit.modules[0].slot.index, 1);
        // Drone group expansion: 3 items sharing group 0.
        assert_eq!(container.fit.drones.len(), 3);
        assert!(container.fit.drones.iter().all(|d| d.group_id == 0));
        // Fighter group expansion with ability bitmask (TURRET|ATTACK_MISSILE).
        assert_eq!(container.fit.fighters.len(), 2);
        assert!(container.fit.fighters.iter().all(|f| {
            f.ability.contains(FighterAbility::ATTACK_TURRET)
                && f.ability.contains(FighterAbility::ATTACK_MISSILE)
                && !f.ability.contains(FighterAbility::MISSILES)
        }));
    }

    #[test]
    fn container_injects_tactical_mode_as_online_module() {
        let mut state = state();
        state.tactical_mode_type_id = Some(77);
        let container = build_container(&state);
        let mode = &container.fit.modules[0];
        assert_eq!(mode.slot.slot_type, ef::ItemSlotType::TacticalMode);
        assert_eq!(mode.slot.index, 0);
        assert_eq!(mode.state, ef::ItemState::Online);
    }

    #[test]
    fn container_filters_unreferenced_dynamic_items() {
        let mut state = state();
        state.modules = vec![pb::FitModule {
            item: Some(fit_module::Item::DynamicId(1)),
            slot_type: pb::SlotType::Low as i32,
            index: 0,
            state: pb::slots::SlotState::Online as i32,
            charge_type_id: None,
            subsystem_type: None,
        }];
        state.dynamic_items = vec![
            pb::FitDynamicItem {
                dynamic_id: 1,
                base_type_id: 10,
                attributes: vec![pb::FitDynamicAttribute {
                    attribute_id: 6,
                    value: 1.5,
                }],
            },
            pb::FitDynamicItem {
                dynamic_id: 2,
                base_type_id: 11,
                attributes: vec![],
            },
        ];
        let container = build_container(&state);
        assert_eq!(container.dynamic.len(), 1);
        let item = &container.dynamic[&1];
        assert_eq!(item.base_type, 10);
        assert_eq!(item.dynamic_attributes.get(&6), Some(&1.5));
    }
}
