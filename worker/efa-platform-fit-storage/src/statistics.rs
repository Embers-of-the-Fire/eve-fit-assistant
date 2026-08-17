use eve_fit_os::calculate::Ship;
use eve_fit_os::calculate::item::{Item, SlotType};
use eve_fit_os::constant::patches::attr as patch;

use crate::proto::fit as pb;

/// Standard dogma attribute IDs, mirroring `EveConstAttrID`
/// (packages/efa_constant/lib/eve.dart). Patch attributes are referenced
/// through `eve_fit_os::constant::patches::attr::ATTR_*` instead (never
/// hardcoded negatives).
pub mod attr_id {
    pub const HP: i32 = 9;
    pub const POWER_OUTPUT: i32 = 11;
    pub const MAX_VELOCITY: i32 = 37;
    pub const CAPACITY: i32 = 38;
    pub const CPU_OUTPUT: i32 = 48;
    pub const RECHARGE_RATE: i32 = 55;
    pub const CAPACITOR_CAPACITY: i32 = 482;
    pub const MAX_TARGET_RANGE: i32 = 76;
    pub const MAX_LOCKED_TARGETS: i32 = 192;
    pub const SCAN_RADAR_STRENGTH: i32 = 208;
    pub const SCAN_LADAR_STRENGTH: i32 = 209;
    pub const SCAN_MAGNETOMETRIC_STRENGTH: i32 = 210;
    pub const SCAN_GRAVIMETRIC_STRENGTH: i32 = 211;
    pub const SHIELD_CAPACITY: i32 = 263;
    pub const ARMOR_HP: i32 = 265;
    pub const ARMOR_EM_RESONANCE: i32 = 267;
    pub const ARMOR_EXPLOSIVE_RESONANCE: i32 = 268;
    pub const ARMOR_KINETIC_RESONANCE: i32 = 269;
    pub const ARMOR_THERMAL_RESONANCE: i32 = 270;
    pub const SHIELD_EM_RESONANCE: i32 = 271;
    pub const SHIELD_EXPLOSIVE_RESONANCE: i32 = 272;
    pub const SHIELD_KINETIC_RESONANCE: i32 = 273;
    pub const SHIELD_THERMAL_RESONANCE: i32 = 274;
    pub const DRONE_CAPACITY: i32 = 283;
    pub const MAX_ACTIVE_DRONES: i32 = 352;
    pub const DRONE_CONTROL_DISTANCE: i32 = 458;
    pub const SIGNATURE_RADIUS: i32 = 552;
    pub const SCAN_RESOLUTION: i32 = 564;
    pub const SHIP_MAINTENANCE_BAY_CAPACITY: i32 = 908;
    pub const FUEL_BAY_CAPACITY: i32 = 910;
    pub const FLEET_HANGAR_CAPACITY: i32 = 912;
    pub const HULL_KINETIC_RESONANCE: i32 = 109;
    pub const HULL_THERMAL_RESONANCE: i32 = 110;
    pub const HULL_EXPLOSIVE_RESONANCE: i32 = 111;
    pub const HULL_EM_RESONANCE: i32 = 113;
    pub const UPGRADE_CAPACITY: i32 = 1132;
    pub const DRONE_BANDWIDTH: i32 = 1271;
    pub const DRONE_BANDWIDTH_LOAD: i32 = 1273;
    pub const MINING_HOLD_CAPACITY: i32 = 1556;
    pub const GAS_HOLD_CAPACITY: i32 = 1557;
    pub const MINERAL_HOLD_CAPACITY: i32 = 1558;
    pub const COMMAND_CENTER_HOLD_CAPACITY: i32 = 1646;
    pub const PLANETARY_COMMODITIES_HOLD_CAPACITY: i32 = 1653;
    pub const FIGHTER_CAPACITY: i32 = 2055;
    pub const ICE_HOLD_CAPACITY: i32 = 3136;
}

/// `item.attributes[id].value ?? base_value ?? 0.0` (spec §10).
fn get(item: &Item, attribute_id: i32) -> f64 {
    get_or(item, attribute_id, 0.0)
}

/// Resonance reads default to 1.0.
fn get_or(item: &Item, attribute_id: i32, default: f64) -> f64 {
    item.attributes
        .get(&attribute_id)
        .map(|a| a.value.unwrap_or(a.base_value))
        .unwrap_or(default)
}

/// Capacitor stability point, EVE University formula; port of
/// `lib/utils/native/algo/capacitor.dart`. Returns a percentage 0..100, or -1
/// on negative discriminant.
pub fn capacitor_stable_at(capacity: f64, target_recharge_rate: f64, recharge_time_ms: f64) -> f64 {
    let v = target_recharge_rate;
    let t = recharge_time_ms / 1000.0;
    let cm = capacity;

    let delta = -10.0 * cm * t * v + 25.0 * cm * cm;
    if delta < 0.0 {
        return -1.0;
    }
    let sqrt_delta = delta.sqrt();
    let solve1 = (5.0 * cm + sqrt_delta - v * t) / (10.0 * cm);
    let solve2 = (5.0 * cm - sqrt_delta - v * t) / (10.0 * cm);
    solve1.max(solve2) * 100.0
}

fn defense_layer(
    hull: &Item,
    hp_attribute: i32,
    ehp_attribute: i32,
    em_resonance: i32,
    thermal_resonance: i32,
    kinetic_resonance: i32,
    explosive_resonance: i32,
) -> pb::snapshot_statistics::DefenseLayer {
    pb::snapshot_statistics::DefenseLayer {
        hp: get(hull, hp_attribute),
        ehp: get(hull, ehp_attribute),
        resistances: pb::DamageProfile {
            em: 1.0 - get_or(hull, em_resonance, 1.0),
            thermal: 1.0 - get_or(hull, thermal_resonance, 1.0),
            kinetic: 1.0 - get_or(hull, kinetic_resonance, 1.0),
            explosive: 1.0 - get_or(hull, explosive_resonance, 1.0),
        },
    }
}

/// Field-for-field port of the app's `_statistics`
/// (lib/features/fit_io/snapshot_export.dart), spec §10.
pub fn build_statistics(ship: &Ship) -> pb::SnapshotStatistics {
    let hull = &ship.hull;
    let character = &ship.character;

    let depletes_in = get(hull, patch::ATTR_CAPACITOR_DEPLETES_IN);
    let is_stable = depletes_in <= 0.0;
    let peak_load = get(hull, patch::ATTR_CAPACITOR_PEAK_LOAD);
    let peak_delta = get(hull, patch::ATTR_CAPACITOR_PEAK_DELTA);
    let recharge_time_ms = get(hull, attr_id::RECHARGE_RATE);
    let capacity = get(hull, attr_id::CAPACITOR_CAPACITY);
    let stable_fraction = is_stable.then(|| {
        capacitor_stable_at(capacity, peak_load, recharge_time_ms).clamp(0.0, 100.0) / 100.0
    });

    let fighter_dps = get(hull, patch::ATTR_FIGHTER_DAMAGE_PER_SECOND);
    let fighter_volley: f64 = ship
        .modules
        .iter()
        .filter(|item| matches!(item.slot.slot_type, SlotType::Fighter { .. }))
        .map(|item| {
            get(item, patch::ATTR_FIGHTER_DAMAGE_MISSILES)
                + get(item, patch::ATTR_FIGHTER_DAMAGE_ATTACK_TURRET)
                + get(item, patch::ATTR_FIGHTER_DAMAGE_ATTACK_MISSILE)
        })
        .sum();

    let capacitor = pb::snapshot_statistics::Capacitor {
        is_stable,
        stable_fraction,
        peak_use_rate: peak_load,
        peak_recharge_rate: peak_load + peak_delta,
        capacity_gj: capacity,
        recharge_time_s: recharge_time_ms / 1000.0,
        depletes_in_s: (!is_stable).then_some(depletes_in),
    };

    let weapons = pb::snapshot_statistics::Weapons {
        dps_total: get(hull, patch::ATTR_DAMAGE_PER_SECOND_WITHOUT_RELOAD) + fighter_dps,
        dps_with_reload: get(hull, patch::ATTR_DAMAGE_PER_SECOND_WITH_RELOAD) + fighter_dps,
        alpha_volley: get(hull, patch::ATTR_DAMAGE_ALPHA) + fighter_volley,
    };

    let cpu_output = get(hull, attr_id::CPU_OUTPUT);
    let power_output = get(hull, attr_id::POWER_OUTPUT);
    let resources = pb::snapshot_statistics::Resources {
        cpu_used: cpu_output - get(hull, patch::ATTR_CPU_FREE),
        cpu_total: cpu_output,
        powergrid_used: power_output - get(hull, patch::ATTR_POWER_FREE),
        powergrid_total: power_output,
        calibration_used: get(hull, patch::ATTR_UPGRADE_USED),
        calibration_total: get(hull, attr_id::UPGRADE_CAPACITY),
        drone_bandwidth_used: get(hull, attr_id::DRONE_BANDWIDTH_LOAD),
        drone_bandwidth_total: get(hull, attr_id::DRONE_BANDWIDTH),
    };

    let mobility = pb::snapshot_statistics::Mobility {
        max_velocity_ms: get(hull, attr_id::MAX_VELOCITY),
        warp_speed_au_s: get(hull, patch::ATTR_WARP_SPEED),
        align_time_s: get(hull, patch::ATTR_ALIGN_TIME),
        signature_radius_m: get(hull, attr_id::SIGNATURE_RADIUS),
    };

    let targeting = pb::snapshot_statistics::Targeting {
        max_target_range_m: get(hull, attr_id::MAX_TARGET_RANGE),
        scan_resolution_mm: get(hull, attr_id::SCAN_RESOLUTION),
        max_locked_targets: get(hull, attr_id::MAX_LOCKED_TARGETS).round() as u32,
        radar_strength: get(hull, attr_id::SCAN_RADAR_STRENGTH),
        ladar_strength: get(hull, attr_id::SCAN_LADAR_STRENGTH),
        magnetometric_strength: get(hull, attr_id::SCAN_MAGNETOMETRIC_STRENGTH),
        gravimetric_strength: get(hull, attr_id::SCAN_GRAVIMETRIC_STRENGTH),
    };

    let drones = pb::snapshot_statistics::Drones {
        max_active_drones: get(character, attr_id::MAX_ACTIVE_DRONES).round() as u32,
        control_range_m: get(character, attr_id::DRONE_CONTROL_DISTANCE),
        bay_capacity_m3: get(hull, attr_id::DRONE_CAPACITY),
        bay_used_m3: get(hull, patch::ATTR_DRONE_CAPACITY_LOAD),
    };

    // Specialized holds, in spec order, emitted when nonzero.
    let hold_kinds = [
        (
            pb::snapshot_statistics::cargo::HoldKind::FleetHangar,
            attr_id::FLEET_HANGAR_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::ShipMaintenanceBay,
            attr_id::SHIP_MAINTENANCE_BAY_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::MiningHold,
            attr_id::MINING_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::GasHold,
            attr_id::GAS_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::MineralHold,
            attr_id::MINERAL_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::IceHold,
            attr_id::ICE_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::CommandCenterHold,
            attr_id::COMMAND_CENTER_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::PlanetaryCommoditiesHold,
            attr_id::PLANETARY_COMMODITIES_HOLD_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::FuelBay,
            attr_id::FUEL_BAY_CAPACITY,
        ),
        (
            pb::snapshot_statistics::cargo::HoldKind::FighterBay,
            attr_id::FIGHTER_CAPACITY,
        ),
    ];
    let holds = hold_kinds
        .into_iter()
        .filter_map(|(kind, attribute)| {
            let capacity = get(hull, attribute);
            (capacity != 0.0).then_some(pb::snapshot_statistics::cargo::Hold {
                kind: kind as i32,
                capacity_m3: capacity,
            })
        })
        .collect();

    let cargo = pb::snapshot_statistics::Cargo {
        mass_kg: get(hull, patch::ATTR_TOTAL_MASS),
        capacity_m3: get(hull, attr_id::CAPACITY),
        holds,
    };

    pb::SnapshotStatistics {
        capacitor,
        weapons,
        resources,
        shield: defense_layer(
            hull,
            attr_id::SHIELD_CAPACITY,
            patch::ATTR_SHIELD_EHP,
            attr_id::SHIELD_EM_RESONANCE,
            attr_id::SHIELD_THERMAL_RESONANCE,
            attr_id::SHIELD_KINETIC_RESONANCE,
            attr_id::SHIELD_EXPLOSIVE_RESONANCE,
        ),
        armor: defense_layer(
            hull,
            attr_id::ARMOR_HP,
            patch::ATTR_ARMOR_EHP,
            attr_id::ARMOR_EM_RESONANCE,
            attr_id::ARMOR_THERMAL_RESONANCE,
            attr_id::ARMOR_KINETIC_RESONANCE,
            attr_id::ARMOR_EXPLOSIVE_RESONANCE,
        ),
        hull: defense_layer(
            hull,
            attr_id::HP,
            patch::ATTR_HULL_EHP,
            attr_id::HULL_EM_RESONANCE,
            attr_id::HULL_THERMAL_RESONANCE,
            attr_id::HULL_KINETIC_RESONANCE,
            attr_id::HULL_EXPLOSIVE_RESONANCE,
        ),
        mobility,
        targeting,
        drones,
        cargo,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use eve_fit_os::calculate::item::Attribute;
    use std::collections::HashMap;

    fn item_with(attrs: &[(i32, f64)]) -> Item {
        let mut item = Item::new_fake(0);
        item.attributes = attrs
            .iter()
            .map(|&(id, value)| {
                let mut attribute = Attribute::new_base(value);
                attribute.value = Some(value);
                (id, attribute)
            })
            .collect::<HashMap<_, _>>();
        item
    }

    #[test]
    fn capacitor_stable_point_matches_reference() {
        // EVE Uni formula: 1000 GJ, 10 GJ/s use, 250 s recharge → stable at 25%.
        let stable = capacitor_stable_at(1000.0, 10.0, 250_000.0);
        assert_eq!(stable, 25.0);
        // Zero use → stable at 100%.
        assert_eq!(capacitor_stable_at(1000.0, 0.0, 250_000.0), 100.0);
        // Negative discriminant → -1.
        assert_eq!(capacitor_stable_at(1.0, 1e9, 1.0), -1.0);
    }

    #[test]
    fn get_prefers_calculated_value_then_base_then_default() {
        let mut with_base = Attribute::new_base(3.0);
        let item = Item {
            attributes: HashMap::from([(1, with_base.clone())]),
            ..Item::new_fake(0)
        };
        assert_eq!(get(&item, 1), 3.0);
        with_base.value = Some(5.0);
        let item = Item {
            attributes: HashMap::from([(1, with_base)]),
            ..Item::new_fake(0)
        };
        assert_eq!(get(&item, 1), 5.0);
        assert_eq!(get(&item, 2), 0.0);
        assert_eq!(get_or(&item, 2, 1.0), 1.0);
    }

    #[test]
    fn statistics_golden_minimal() {
        let mut ship = Ship::new(0);
        ship.hull = item_with(&[
            (attr_id::CAPACITOR_CAPACITY, 1000.0),
            (attr_id::RECHARGE_RATE, 250_000.0),
            (patch::ATTR_CAPACITOR_PEAK_LOAD, 10.0),
            (patch::ATTR_CAPACITOR_PEAK_DELTA, 15.0),
            (patch::ATTR_CAPACITOR_DEPLETES_IN, 0.0),
            (patch::ATTR_DAMAGE_PER_SECOND_WITHOUT_RELOAD, 100.0),
            (patch::ATTR_DAMAGE_PER_SECOND_WITH_RELOAD, 90.0),
            (patch::ATTR_FIGHTER_DAMAGE_PER_SECOND, 5.0),
            (patch::ATTR_DAMAGE_ALPHA, 400.0),
            (attr_id::CPU_OUTPUT, 500.0),
            (patch::ATTR_CPU_FREE, 125.0),
            (attr_id::POWER_OUTPUT, 1000.0),
            (patch::ATTR_POWER_FREE, 250.0),
            (patch::ATTR_UPGRADE_USED, 100.0),
            (attr_id::UPGRADE_CAPACITY, 400.0),
            (attr_id::DRONE_BANDWIDTH_LOAD, 25.0),
            (attr_id::DRONE_BANDWIDTH, 50.0),
            (attr_id::SHIELD_CAPACITY, 2000.0),
            (patch::ATTR_SHIELD_EHP, 3000.0),
            (attr_id::SHIELD_EM_RESONANCE, 0.8),
            (attr_id::ARMOR_HP, 1500.0),
            (patch::ATTR_ARMOR_EHP, 2000.0),
            (attr_id::HP, 1000.0),
            (patch::ATTR_HULL_EHP, 1000.0),
            (attr_id::MAX_VELOCITY, 300.0),
            (patch::ATTR_WARP_SPEED, 3.0),
            (patch::ATTR_ALIGN_TIME, 6.5),
            (attr_id::SIGNATURE_RADIUS, 100.0),
            (attr_id::MAX_TARGET_RANGE, 60_000.0),
            (attr_id::SCAN_RESOLUTION, 400.0),
            (attr_id::MAX_LOCKED_TARGETS, 7.0),
            (attr_id::SCAN_RADAR_STRENGTH, 12.0),
            (attr_id::SCAN_LADAR_STRENGTH, 0.0),
            (attr_id::SCAN_MAGNETOMETRIC_STRENGTH, 0.0),
            (attr_id::SCAN_GRAVIMETRIC_STRENGTH, 0.0),
            (attr_id::DRONE_CAPACITY, 125.0),
            (patch::ATTR_DRONE_CAPACITY_LOAD, 75.0),
            (patch::ATTR_TOTAL_MASS, 1e7),
            (attr_id::CAPACITY, 500.0),
            (attr_id::FLEET_HANGAR_CAPACITY, 10_000.0),
        ]);
        ship.character = item_with(&[
            (attr_id::MAX_ACTIVE_DRONES, 5.0),
            (attr_id::DRONE_CONTROL_DISTANCE, 40_000.0),
        ]);

        let stats = build_statistics(&ship);
        let capacitor = stats.capacitor;
        assert!(capacitor.is_stable);
        assert_eq!(capacitor.peak_use_rate, 10.0);
        assert_eq!(capacitor.peak_recharge_rate, 25.0);
        assert_eq!(capacitor.capacity_gj, 1000.0);
        assert_eq!(capacitor.recharge_time_s, 250.0);
        assert!(capacitor.depletes_in_s.is_none());
        let stable = capacitor.stable_fraction.unwrap();
        assert_eq!(stable, 0.25);

        let weapons = stats.weapons;
        assert_eq!(weapons.dps_total, 105.0);
        assert_eq!(weapons.dps_with_reload, 95.0);
        assert_eq!(weapons.alpha_volley, 400.0);

        let resources = stats.resources;
        assert_eq!(resources.cpu_used, 375.0);
        assert_eq!(resources.cpu_total, 500.0);
        assert_eq!(resources.powergrid_used, 750.0);
        assert_eq!(resources.calibration_used, 100.0);
        assert_eq!(resources.calibration_total, 400.0);
        assert_eq!(resources.drone_bandwidth_used, 25.0);
        assert_eq!(resources.drone_bandwidth_total, 50.0);

        let shield = stats.shield;
        assert_eq!(shield.hp, 2000.0);
        assert_eq!(shield.ehp, 3000.0);
        let resistances = shield.resistances;
        assert!((resistances.em - 0.2).abs() < 1e-12);
        // Unset resonances default to 1.0 → zero resistance.
        assert_eq!(resistances.thermal, 0.0);

        let targeting = stats.targeting;
        assert_eq!(targeting.max_locked_targets, 7);

        let drones = stats.drones;
        assert_eq!(drones.max_active_drones, 5);
        assert_eq!(drones.control_range_m, 40_000.0);
        assert_eq!(drones.bay_used_m3, 75.0);

        let cargo = stats.cargo;
        assert_eq!(cargo.mass_kg, 1e7);
        assert_eq!(cargo.capacity_m3, 500.0);
        assert_eq!(cargo.holds.len(), 1);
        assert_eq!(
            cargo.holds[0].kind,
            pb::snapshot_statistics::cargo::HoldKind::FleetHangar as i32
        );
        assert_eq!(cargo.holds[0].capacity_m3, 10_000.0);
    }

    #[test]
    fn unstable_capacitor_reports_depletes_in() {
        let mut ship = Ship::new(0);
        ship.hull = item_with(&[(patch::ATTR_CAPACITOR_DEPLETES_IN, 120.0)]);
        let capacitor = build_statistics(&ship).capacitor;
        assert!(!capacitor.is_stable);
        assert_eq!(capacitor.depletes_in_s, Some(120.0));
        assert!(capacitor.stable_fraction.is_none());
    }
}
