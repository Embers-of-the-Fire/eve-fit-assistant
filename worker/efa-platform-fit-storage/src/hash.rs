use sha2::{Digest, Sha256};

use crate::proto::fit as pb;

/// Canonical form of a `FitState` (spec §5.1): every repeated collection is
/// sorted by a stable key so identical fits hash identically regardless of
/// wire ordering. Map fields are deterministic already (`BTreeMap`, see
/// build.rs).
pub fn canonical_state(state: &pb::FitState) -> pb::FitState {
    let mut state = state.clone();

    state.modules.sort_by_key(|m| (m.slot_type, m.index));
    state.available_tactical_modes.sort_by_key(|m| m.type_id);
    state
        .drones
        .sort_by_key(|d| (d.type_id, d.state, d.quantity));
    for fighter in &mut state.fighters {
        fighter.abilities.sort();
    }
    state.fighters.sort_by_key(|f| {
        (
            f.type_id,
            f.quantity,
            f.max_squadron_size,
            f.group,
            f.abilities.clone(),
        )
    });
    state.implants.sort_by_key(|i| i.slot_index);
    state.boosters.sort_by_key(|b| b.slot_index);
    state.skills.sort_by_key(|s| (s.type_id, s.level));
    state.dynamic_items.sort_by_key(|d| d.dynamic_id);
    for item in &mut state.dynamic_items {
        item.attributes.sort_by_key(|a| a.attribute_id);
    }

    state
}

/// `lowercase_hex(sha256(bytes))`, matching
/// `bootstrap/remote/hash.py::content_hash()`.
pub fn fit_hash(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    hasher
        .finalize()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::fit::fit_module;
    use prost::Message;
    use std::collections::BTreeMap;

    fn sample_state() -> pb::FitState {
        pb::FitState {
            ship_type_id: 11184,
            layout: pb::SnapshotShipLayout {
                high_slots: 4,
                medium_slots: 4,
                low_slots: 4,
                rig_slots: 3,
                subsystem_slots: 0,
                service_slots: 0,
                turret_hardpoints: 4,
                launcher_hardpoints: 2,
                fighter_tubes: 0,
            },
            available_tactical_modes: vec![],
            tactical_mode_type_id: None,
            modules: vec![
                pb::FitModule {
                    item: Some(fit_module::Item::TypeId(3001)),
                    slot_type: pb::SlotType::High as i32,
                    index: 1,
                    state: pb::slots::SlotState::Active as i32,
                    charge_type_id: Some(200),
                    subsystem_type: None,
                },
                pb::FitModule {
                    item: Some(fit_module::Item::DynamicId(7)),
                    slot_type: pb::SlotType::High as i32,
                    index: 0,
                    state: pb::slots::SlotState::Passive as i32,
                    charge_type_id: None,
                    subsystem_type: None,
                },
                pb::FitModule {
                    item: Some(fit_module::Item::TypeId(3002)),
                    slot_type: pb::SlotType::Low as i32,
                    index: 0,
                    state: pb::slots::SlotState::Online as i32,
                    charge_type_id: None,
                    subsystem_type: None,
                },
            ],
            drones: vec![
                pb::FitDrone {
                    type_id: 2488,
                    state: pb::slots::SlotState::Active as i32,
                    quantity: 2,
                },
                pb::FitDrone {
                    type_id: 2488,
                    state: pb::slots::SlotState::Passive as i32,
                    quantity: 1,
                },
            ],
            fighters: vec![pb::FitFighter {
                type_id: 40552,
                quantity: 2,
                max_squadron_size: 9,
                group: pb::snapshot_fighter::SquadronGroup::Light as i32,
                abilities: vec![
                    pb::snapshot_fighter::Ability::AttackMissiles as i32,
                    pb::snapshot_fighter::Ability::Turret as i32,
                ],
            }],
            implants: vec![
                pb::FitImplant {
                    slot_index: 10,
                    type_id: Some(10232),
                    state: pb::slots::SlotState::Active as i32,
                },
                pb::FitImplant {
                    slot_index: 1,
                    type_id: None,
                    state: pb::slots::SlotState::Passive as i32,
                },
            ],
            boosters: vec![pb::FitBooster {
                slot_index: 2,
                type_id: 15466,
                state: pb::slots::SlotState::Active as i32,
            }],
            skills: vec![
                pb::FitSkill {
                    type_id: 3327,
                    level: 5,
                },
                pb::FitSkill {
                    type_id: 3326,
                    level: 4,
                },
            ],
            damage_profile: pb::DamageProfile {
                em: 0.25,
                thermal: 0.25,
                kinetic: 0.25,
                explosive: 0.25,
            },
            dynamic_items: vec![pb::FitDynamicItem {
                dynamic_id: 7,
                base_type_id: 3001,
                attributes: vec![
                    pb::FitDynamicAttribute {
                        attribute_id: 6,
                        value: 20.0,
                    },
                    pb::FitDynamicAttribute {
                        attribute_id: -1,
                        value: 1.5,
                    },
                ],
                type_id: Some(3002),
            }],
            character: Some(pb::FitCharacter {
                character_id: Some("char-1".to_string()),
                names: BTreeMap::from([
                    ("zh".to_string(), "测试".to_string()),
                    ("en".to_string(), "Test".to_string()),
                ]),
            }),
        }
    }

    fn shuffled(state: &pb::FitState) -> pb::FitState {
        let mut s = state.clone();
        s.modules.reverse();
        s.drones.reverse();
        s.implants.reverse();
        s.skills.reverse();
        for f in &mut s.fighters {
            f.abilities.reverse();
        }
        for d in &mut s.dynamic_items {
            d.attributes.reverse();
        }
        if let Some(c) = &mut s.character {
            // BTreeMap keeps keys sorted regardless of insertion order;
            // rebuild to simulate a different wire order.
            let names: BTreeMap<String, String> = c
                .names
                .iter()
                .rev()
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect();
            c.names = names;
        }
        s
    }

    #[test]
    fn canonical_hash_is_permutation_invariant() {
        let state = sample_state();
        let hash_a = fit_hash(&canonical_state(&state).encode_to_vec());
        let hash_b = fit_hash(&canonical_state(&shuffled(&state)).encode_to_vec());
        assert_eq!(hash_a, hash_b);
        assert_eq!(hash_a.len(), 64);
    }

    #[test]
    fn canonical_hash_is_fighter_order_invariant() {
        let mut state = sample_state();
        state.fighters = vec![
            pb::FitFighter {
                type_id: 40552,
                quantity: 2,
                max_squadron_size: 9,
                group: pb::snapshot_fighter::SquadronGroup::Light as i32,
                abilities: vec![
                    pb::snapshot_fighter::Ability::AttackMissiles as i32,
                    pb::snapshot_fighter::Ability::Turret as i32,
                ],
            },
            pb::FitFighter {
                type_id: 40552,
                quantity: 2,
                max_squadron_size: 12,
                group: pb::snapshot_fighter::SquadronGroup::Heavy as i32,
                abilities: vec![pb::snapshot_fighter::Ability::Turret as i32],
            },
        ];
        let mut swapped = state.clone();
        swapped.fighters.reverse();
        swapped.fighters[1].abilities.reverse();
        assert_eq!(
            fit_hash(&canonical_state(&state).encode_to_vec()),
            fit_hash(&canonical_state(&swapped).encode_to_vec())
        );
    }

    #[test]
    fn canonical_bytes_change_with_content() {
        let state = sample_state();
        let mut other = state.clone();
        other.ship_type_id = 11186;
        assert_ne!(
            fit_hash(&canonical_state(&state).encode_to_vec()),
            fit_hash(&canonical_state(&other).encode_to_vec())
        );
    }
}
