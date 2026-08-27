use std::collections::HashMap;

use eve_fit_os::calculate::Ship;
use eve_fit_os::calculate::item::SlotType as EngineSlotType;
use eve_fit_os::constant::patches::attr as patch;

use crate::prefetch::SnapshotData;
use crate::proto::{fit as pb, utils};

/// Dogma effects marking turret/launcher hardpoint usage. Same constants the
/// engine's validator uses (`eve-fit-os/src/validate.rs`), matching the data
/// build (`bootstrap/constant.py`: TURRET_EFFECT_ID / LAUNCHER_EFFECT_ID).
const EFFECT_LAUNCHER: i32 = 40;
const EFFECT_TURRET: i32 = 42;

fn snapshot_type(
    data: &SnapshotData,
    icon_urls: &HashMap<i32, String>,
    type_id: i32,
) -> pb::SnapshotType {
    let meta = data.type_meta.get(&type_id);
    pb::SnapshotType {
        type_id: type_id as u32,
        names: meta.map(|m| m.name.clone()).unwrap_or_default(),
        icon: meta.and_then(|m| {
            if m.icon_id.is_none() && m.graphic_id.is_none() {
                None
            } else {
                Some(utils::Icon {
                    graphic_id: m.graphic_id,
                    icon_id: m.icon_id,
                })
            }
        }),
        meta_group: None,
        icon_url: icon_urls.get(&type_id).cloned(),
    }
}

/// Display type of a module plus, for dynamic items, the unmutated base
/// (dogma) type: the type ID, or the dynamic item's mutated type and base
/// type. The mutated type ID is display-only; dogma comes from the base.
fn module_type_ids(state: &pb::FitState, module: &pb::FitModule) -> Option<(i32, Option<i32>)> {
    match &module.item {
        Some(pb::fit_module::Item::TypeId(type_id)) => Some((*type_id as i32, None)),
        Some(pb::fit_module::Item::DynamicId(dynamic_id)) => state
            .dynamic_items
            .iter()
            .find(|d| d.dynamic_id == *dynamic_id)
            .map(|d| {
                let base = d.base_type_id as i32;
                (d.type_id.map(|t| t as i32).unwrap_or(base), Some(base))
            }),
        None => None,
    }
}

/// `is_turret`/`is_launcher` derived from the module's dogma effects (the
/// collection slot metadata the app uses is not part of the platform
/// database).
fn hardpoint_flags(data: &SnapshotData, base_type_id: i32) -> (bool, bool) {
    let effects = data
        .type_dogma
        .get(&base_type_id)
        .map(|item| &item.effects[..])
        .unwrap_or(&[]);
    let is_turret = effects.iter().any(|e| e.effect_id == EFFECT_TURRET);
    let is_launcher = effects.iter().any(|e| e.effect_id == EFFECT_LAUNCHER);
    (is_turret, is_launcher)
}

/// The calculated engine item matching a submitted module (slot type + index).
fn calculated_module(
    ship: &Ship,
    slot_type: EngineSlotType,
    index: i32,
) -> Option<&eve_fit_os::calculate::item::Item> {
    ship.modules
        .iter()
        .find(|item| item.slot.slot_type == slot_type && item.slot.index == Some(index))
}

fn snapshot_module(
    data: &SnapshotData,
    icon_urls: &HashMap<i32, String>,
    state: &pb::FitState,
    ship: &Ship,
    module: &pb::FitModule,
) -> Option<pb::SnapshotModule> {
    let (type_id, origin_type_id) = module_type_ids(state, module)?;
    let engine_slot_type = match pb::SlotType::try_from(module.slot_type) {
        Ok(pb::SlotType::High) => Some(EngineSlotType::High),
        Ok(pb::SlotType::Medium) => Some(EngineSlotType::Medium),
        Ok(pb::SlotType::Low) => Some(EngineSlotType::Low),
        Ok(pb::SlotType::Rig) => Some(EngineSlotType::Rig),
        Ok(pb::SlotType::Subsystem) => Some(EngineSlotType::SubSystem),
        Ok(pb::SlotType::Service) => Some(EngineSlotType::Service),
        Err(_) => None,
    };
    let calculated =
        engine_slot_type.and_then(|st| calculated_module(ship, st, module.index as i32));

    let charge = module
        .charge_type_id
        .map(|charge_type_id| pb::SnapshotCharge {
            r#type: snapshot_type(data, icon_urls, charge_type_id as i32),
            // Rounds loaded per module (dogma chargeAmount), read from the
            // module's calculated item — the patch attaches it to the module.
            quantity: calculated.map(|item| {
                item.attributes
                    .get(&patch::ATTR_CHARGE_AMOUNT)
                    .map(|a| a.value.unwrap_or(a.base_value))
                    .unwrap_or(0.0)
                    .round() as u32
            }),
        });

    let (is_turret, is_launcher) = if module.slot_type == pb::SlotType::High as i32 {
        // Hardpoint flags come from dogma effects, which dynamic items
        // inherit from their base type.
        hardpoint_flags(data, origin_type_id.unwrap_or(type_id))
    } else {
        (false, false)
    };

    Some(pb::SnapshotModule {
        r#type: snapshot_type(data, icon_urls, type_id),
        state: module.state,
        charge,
        is_turret: Some(is_turret),
        is_launcher: Some(is_launcher),
        origin_type: origin_type_id.map(|base| snapshot_type(data, icon_urls, base)),
        related_values: Vec::new(),
    })
}

fn find_module(
    state: &pb::FitState,
    slot_type: pb::SlotType,
    index: u32,
) -> Option<&pb::FitModule> {
    state
        .modules
        .iter()
        .find(|m| m.slot_type == slot_type as i32 && m.index == index)
}

/// Assemble the stored `FitSnapshot` (version 1), spec §9/§11.
pub fn assemble(
    request: &pb::FitUploadRequest,
    state: &pb::FitState,
    ship: &Ship,
    data: &SnapshotData,
    icon_urls: &HashMap<i32, String>,
    created_at_ms: i64,
) -> pb::FitSnapshot {
    let layout = state.layout;

    let rack = |slot_type: pb::SlotType, count: u32| -> Vec<pb::SnapshotSlot> {
        (0..count)
            .map(|index| pb::SnapshotSlot {
                index,
                item: find_module(state, slot_type, index)
                    .and_then(|m| snapshot_module(data, icon_urls, state, ship, m)),
            })
            .collect()
    };

    let subsystem_slots = (0..layout.subsystem_slots)
        .map(|index| {
            let module = find_module(state, pb::SlotType::Subsystem, index);
            pb::SnapshotSubsystemSlot {
                index,
                subsystem_type: module
                    .and_then(|m| m.subsystem_type)
                    .unwrap_or(pb::subsystem::SubsystemType::Unknown as i32),
                item: module.and_then(|m| snapshot_module(data, icon_urls, state, ship, m)),
            }
        })
        .collect();

    let tactical_mode = state.tactical_mode_type_id.and_then(|selected| {
        state
            .available_tactical_modes
            .iter()
            .find(|mode| mode.type_id == selected)
            .map(|mode| pb::SnapshotTacticalMode {
                r#type: snapshot_type(data, icon_urls, mode.type_id as i32),
                variant: mode.variant,
            })
    });

    let drones = state
        .drones
        .iter()
        .map(|drone| pb::SnapshotDrone {
            r#type: snapshot_type(data, icon_urls, drone.type_id as i32),
            state: drone.state,
            quantity: drone.quantity,
        })
        .collect();

    let fighters = state
        .fighters
        .iter()
        .map(|fighter| pb::SnapshotFighter {
            r#type: snapshot_type(data, icon_urls, fighter.type_id as i32),
            // Fighters are always active (app convention, snapshot_export.dart).
            state: pb::slots::SlotState::Active as i32,
            quantity: fighter.quantity,
            max_squadron_size: fighter.max_squadron_size,
            group: fighter.group,
            abilities: fighter.abilities.clone(),
            related_values: Vec::new(),
        })
        .collect();

    // All 10 implant slots ascending; empty slots have no `item`.
    let implants = (1..=10u32)
        .map(|slot_index| {
            let implant = state.implants.iter().find(|i| i.slot_index == slot_index);
            let item = implant.and_then(|i| {
                i.type_id.map(|type_id| pb::SnapshotModule {
                    r#type: snapshot_type(data, icon_urls, type_id as i32),
                    state: i.state,
                    charge: None,
                    is_turret: Some(false),
                    is_launcher: Some(false),
                    origin_type: None,
                    related_values: Vec::new(),
                })
            });
            pb::SnapshotImplant { slot_index, item }
        })
        .collect();

    let boosters = state
        .boosters
        .iter()
        .map(|booster| pb::SnapshotBooster {
            slot_index: booster.slot_index,
            r#type: snapshot_type(data, icon_urls, booster.type_id as i32),
            state: booster.state,
        })
        .collect();

    let character = pb::SnapshotCharacter {
        character_id: state
            .character
            .as_ref()
            .and_then(|c| c.character_id.clone()),
        builtin: pb::snapshot_character::Builtin::None as i32,
        names: state
            .character
            .as_ref()
            .map(|c| c.names.clone())
            .unwrap_or_default(),
    };

    pb::FitSnapshot {
        version: 1,
        header: pb::SnapshotHeader {
            fit_name: request.fit_name.clone(),
            description: request.description.clone(),
            last_modified_ms: request.last_modified_ms,
            created_at_ms,
            generator: request.generator.clone(),
            checkout_id: None,
            server_id: Some(request.server_id.clone()),
        },
        ship: pb::SnapshotShip {
            r#type: snapshot_type(data, icon_urls, state.ship_type_id as i32),
            layout,
            available_tactical_modes: state
                .available_tactical_modes
                .iter()
                .map(|mode| pb::SnapshotTacticalMode {
                    r#type: snapshot_type(data, icon_urls, mode.type_id as i32),
                    variant: mode.variant,
                })
                .collect(),
        },
        high_slots: rack(pb::SlotType::High, layout.high_slots),
        medium_slots: rack(pb::SlotType::Medium, layout.medium_slots),
        low_slots: rack(pb::SlotType::Low, layout.low_slots),
        rig_slots: rack(pb::SlotType::Rig, layout.rig_slots),
        subsystem_slots,
        service_slots: rack(pb::SlotType::Service, layout.service_slots),
        tactical_mode,
        drones,
        fighters,
        implants,
        boosters,
        character,
        damage_profile: state.damage_profile,
        statistics: Some(crate::statistics::build_statistics(ship)),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::provider::TypeDogmaItem;
    use eve_fit_os::fit::{Type as EngineType, TypeDogmaEffect};

    fn data() -> SnapshotData {
        let mut data = SnapshotData::default();
        data.type_dogma.insert(
            200,
            TypeDogmaItem {
                attributes: Vec::new(),
                effects: vec![
                    TypeDogmaEffect {
                        effect_id: EFFECT_TURRET,
                        is_default: true,
                    },
                    TypeDogmaEffect {
                        effect_id: 12,
                        is_default: true,
                    },
                ],
            },
        );
        data.type_dogma.insert(
            201,
            TypeDogmaItem {
                attributes: Vec::new(),
                effects: vec![TypeDogmaEffect {
                    effect_id: EFFECT_LAUNCHER,
                    is_default: true,
                }],
            },
        );
        data.type_meta.insert(
            100,
            crate::proto::platform_data::PlatformTypeMeta {
                type_id: 100,
                name: [("en".to_string(), "Test Ship".to_string())]
                    .into_iter()
                    .collect(),
                icon_id: Some(42),
                graphic_id: None,
            },
        );
        data.type_meta.insert(
            210,
            crate::proto::platform_data::PlatformTypeMeta {
                type_id: 210,
                name: [("en".to_string(), "Mutated Launcher".to_string())]
                    .into_iter()
                    .collect(),
                icon_id: Some(43),
                graphic_id: None,
            },
        );
        data.types.insert(
            100,
            EngineType {
                group_id: 1,
                category_id: 6,
                capacity: None,
                mass: None,
                radius: None,
                volume: None,
            },
        );
        data
    }

    fn request(state: pb::FitState) -> pb::FitUploadRequest {
        pb::FitUploadRequest {
            server_id: "tranquility".to_string(),
            snapshot_hash: "abc".to_string(),
            fit_name: "test".to_string(),
            description: Some("desc".to_string()),
            last_modified_ms: 123,
            generator: Some("test/0.1".to_string()),
            fit: state,
        }
    }

    fn state() -> pb::FitState {
        pb::FitState {
            ship_type_id: 100,
            layout: pb::SnapshotShipLayout {
                high_slots: 2,
                medium_slots: 1,
                low_slots: 0,
                rig_slots: 1,
                subsystem_slots: 1,
                service_slots: 0,
                turret_hardpoints: 2,
                launcher_hardpoints: 0,
                fighter_tubes: 0,
            },
            modules: vec![
                pb::FitModule {
                    item: Some(pb::fit_module::Item::TypeId(200)),
                    slot_type: pb::SlotType::High as i32,
                    index: 0,
                    state: pb::slots::SlotState::Active as i32,
                    charge_type_id: Some(300),
                    subsystem_type: None,
                },
                pb::FitModule {
                    item: Some(pb::fit_module::Item::DynamicId(5)),
                    slot_type: pb::SlotType::High as i32,
                    index: 1,
                    state: pb::slots::SlotState::Online as i32,
                    charge_type_id: None,
                    subsystem_type: None,
                },
                pb::FitModule {
                    item: Some(pb::fit_module::Item::TypeId(202)),
                    slot_type: pb::SlotType::Subsystem as i32,
                    index: 0,
                    state: pb::slots::SlotState::Online as i32,
                    charge_type_id: None,
                    subsystem_type: Some(pb::subsystem::SubsystemType::Defensive as i32),
                },
            ],
            dynamic_items: vec![pb::FitDynamicItem {
                dynamic_id: 5,
                base_type_id: 201,
                attributes: vec![],
                type_id: Some(210),
            }],
            implants: vec![pb::FitImplant {
                slot_index: 3,
                type_id: Some(900),
                state: pb::slots::SlotState::Active as i32,
            }],
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
    fn snapshot_layout_and_hardpoints() {
        let data = data();
        let state = state();
        let ship = Ship::new(100);
        let icon_urls: HashMap<i32, String> = [(100, "https://cdn.example/icon.png".to_string())]
            .into_iter()
            .collect();
        let snapshot = assemble(
            &request(state.clone()),
            &state,
            &ship,
            &data,
            &icon_urls,
            999,
        );

        assert_eq!(snapshot.version, 1);
        let header = snapshot.header;
        assert_eq!(header.fit_name, "test");
        assert_eq!(header.created_at_ms, 999);
        assert_eq!(header.server_id.as_deref(), Some("tranquility"));
        assert!(header.checkout_id.is_none());

        let ship_type = snapshot.ship.r#type;
        assert_eq!(
            ship_type.names.get("en").map(String::as_str),
            Some("Test Ship")
        );
        assert_eq!(ship_type.icon.unwrap().icon_id, Some(42));
        // Baked icon URL from the resolver map; unresolved types keep `None`.
        assert_eq!(
            ship_type.icon_url.as_deref(),
            Some("https://cdn.example/icon.png")
        );
        assert!(
            snapshot.high_slots[0]
                .item
                .as_ref()
                .unwrap()
                .r#type
                .icon_url
                .is_none()
        );

        // Rack lists sized exactly to layout.
        assert_eq!(snapshot.high_slots.len(), 2);
        assert_eq!(snapshot.medium_slots.len(), 1);
        assert_eq!(snapshot.low_slots.len(), 0);
        assert_eq!(snapshot.rig_slots.len(), 1);
        assert!(snapshot.rig_slots[0].item.is_none());

        // Turret flag from dogma effects; charge present.
        let turret_mod = snapshot.high_slots[0].item.as_ref().unwrap();
        assert_eq!(turret_mod.r#type.type_id, 200);
        assert_eq!(turret_mod.is_turret, Some(true));
        assert_eq!(turret_mod.is_launcher, Some(false));
        assert!(turret_mod.origin_type.is_none());
        let charge = turret_mod.charge.as_ref().unwrap();
        assert_eq!(charge.r#type.type_id, 300);
        // No calculated item (bare Ship::new) → no quantity.
        assert!(charge.quantity.is_none());

        // Dynamic module: mutated type shown, launcher flag and origin_type
        // from the base type.
        let dyn_mod = snapshot.high_slots[1].item.as_ref().unwrap();
        assert_eq!(dyn_mod.r#type.type_id, 210);
        assert_eq!(
            dyn_mod.r#type.names.get("en").map(String::as_str),
            Some("Mutated Launcher")
        );
        assert_eq!(dyn_mod.is_turret, Some(false));
        assert_eq!(dyn_mod.is_launcher, Some(true));
        assert_eq!(dyn_mod.origin_type.as_ref().unwrap().type_id, 201);

        // Subsystem slot carries its type.
        assert_eq!(snapshot.subsystem_slots.len(), 1);
        assert_eq!(
            snapshot.subsystem_slots[0].subsystem_type,
            pb::subsystem::SubsystemType::Defensive as i32
        );

        // 10 implant slots, one filled.
        assert_eq!(snapshot.implants.len(), 10);
        assert!(snapshot.implants[0].item.is_none());
        let filled = snapshot.implants[2].item.as_ref().unwrap();
        assert_eq!(filled.r#type.type_id, 900);

        // Character defaults.
        let character = snapshot.character;
        assert_eq!(
            character.builtin,
            pb::snapshot_character::Builtin::None as i32
        );
        assert!(character.character_id.is_none());
        assert!(character.names.is_empty());

        assert!(snapshot.statistics.is_some());
    }

    #[test]
    fn snapshot_round_trips_through_protobuf() {
        use prost::Message;
        let data = data();
        let state = state();
        let ship = Ship::new(100);
        let snapshot = assemble(
            &request(state.clone()),
            &state,
            &ship,
            &data,
            &HashMap::new(),
            999,
        );
        let bytes = snapshot.encode_to_vec();
        // Byte comparison: a bare (attribute-less) ship yields a NaN stable
        // fraction, which would fail message equality on NaN != NaN.
        let decoded = pb::FitSnapshot::decode(&bytes[..]).unwrap();
        assert_eq!(decoded.encode_to_vec(), bytes);
    }
}
