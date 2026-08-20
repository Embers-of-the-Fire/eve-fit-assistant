/**
 * The app's bundled `EfaAssets` icon set (`apps/eve-fit-assistant/assets/images/icons/`),
 * mirrored under `src/lib/assets/icons/`. Names are semantic; keep the mapping in sync
 * with the Flutter `EfaAssets` usage in `packages/efa_fit_snapshot`.
 */

import attrAlignTimeIcon from "./assets/icons/attr-align-time.png";
import attrCapacitorChargeIcon from "./assets/icons/attr-capacitor-charge.png";
import attrCargoCapacityIcon from "./assets/icons/attr-cargo-capacity.png";
import attrCpuIcon from "./assets/icons/attr-cpu.png";
import attrDamageAlphaIcon from "./assets/icons/attr-damage-alpha.png";
import attrDmgEmResistanceIcon from "./assets/icons/attr-dmg-em-resistance.png";
import attrDmgExplosiveResistanceIcon from "./assets/icons/attr-dmg-explosive-resistance.png";
import attrDmgKineticResistanceIcon from "./assets/icons/attr-dmg-kinetic-resistance.png";
import attrDmgThermalResistanceIcon from "./assets/icons/attr-dmg-thermal-resistance.png";
import attrDroneIcon from "./assets/icons/attr-drone.png";
import attrDroneRangeIcon from "./assets/icons/attr-drone-range.png";
import attrHpArmorIcon from "./assets/icons/attr-hp-armor.png";
import attrHpHullIcon from "./assets/icons/attr-hp-hull.png";
import attrHpShieldIcon from "./assets/icons/attr-hp-shield.png";
import attrLockNumIcon from "./assets/icons/attr-lock-num.png";
import attrMassIcon from "./assets/icons/attr-mass.png";
import attrPowerIcon from "./assets/icons/attr-power.png";
import attrRigIcon from "./assets/icons/attr-rig.png";
import attrScanGravimetricIcon from "./assets/icons/attr-scan-gravimetric.png";
import attrScanLadarIcon from "./assets/icons/attr-scan-ladar.png";
import attrScanMagnetometricIcon from "./assets/icons/attr-scan-magnetometric.png";
import attrScanRadarIcon from "./assets/icons/attr-scan-radar.png";
import attrScanResolutionIcon from "./assets/icons/attr-scan-resolution.png";
import attrSignatureRadiusIcon from "./assets/icons/attr-signature-radius.png";
import attrSpeedIcon from "./assets/icons/attr-speed.png";
import attrTargetRangeIcon from "./assets/icons/attr-target-range.png";
import attrWarpSpeedIcon from "./assets/icons/attr-warp-speed.png";
import attrWeaponDroneIcon from "./assets/icons/attr-weapon-drone.png";
import attrWeaponTurretIcon from "./assets/icons/attr-weapon-turret.png";
import cargoCommandCenterIcon from "./assets/icons/cargo-command-center.png";
import cargoFleetIcon from "./assets/icons/cargo-fleet.png";
import cargoFuelIcon from "./assets/icons/cargo-fuel.png";
import cargoGasIcon from "./assets/icons/cargo-gas.png";
import cargoIceIcon from "./assets/icons/cargo-ice.png";
import cargoMineralIcon from "./assets/icons/cargo-mineral.png";
import cargoOreIcon from "./assets/icons/cargo-ore.png";
import cargoPlanetaryMaterialsIcon from "./assets/icons/cargo-planetary-materials.png";
import cargoShipIcon from "./assets/icons/cargo-ship.png";
import slotHighIcon from "./assets/icons/slot-high.png";
import slotLowIcon from "./assets/icons/slot-low.png";
import slotMediumIcon from "./assets/icons/slot-medium.png";
import slotRigIcon from "./assets/icons/slot-rig.png";
import slotServiceIcon from "./assets/icons/slot-service.png";
import slotSubsystemIcon from "./assets/icons/slot-subsystem.png";
import slotSubsystemCoreIcon from "./assets/icons/slot-subsystem-core.png";
import slotSubsystemDefensiveIcon from "./assets/icons/slot-subsystem-defensive.png";
import slotSubsystemOffensiveIcon from "./assets/icons/slot-subsystem-offensive.png";
import slotSubsystemPropulsionIcon from "./assets/icons/slot-subsystem-propulsion.png";
import tacticalModeDefenseIcon from "./assets/icons/tactical-mode-defense.png";
import tacticalModeSpeedIcon from "./assets/icons/tactical-mode-speed.png";
import tacticalModeTargetIcon from "./assets/icons/tactical-mode-target.png";
import unknownIcon from "./assets/icons/unknown-icon.png";
import weaponLauncherNumIcon from "./assets/icons/weapon-launcher-num.png";
import weaponTurretNumIcon from "./assets/icons/weapon-turret-num.png";

/** Astro's image pipeline yields `ImageMetadata`; plain Vite yields a URL string. */
function srcOf(mod: string | { src: string }): string {
    return typeof mod === "string" ? mod : mod.src;
}

export const ICONS = {
    capacitor: srcOf(attrCapacitorChargeIcon),
    alpha: srcOf(attrDamageAlphaIcon),
    cpu: srcOf(attrCpuIcon),
    power: srcOf(attrPowerIcon),
    rig: srcOf(attrRigIcon),
    "drone-bandwidth": srcOf(attrWeaponDroneIcon),
    "hp-shield": srcOf(attrHpShieldIcon),
    "hp-armor": srcOf(attrHpArmorIcon),
    "hp-hull": srcOf(attrHpHullIcon),
    "resist-em": srcOf(attrDmgEmResistanceIcon),
    "resist-thermal": srcOf(attrDmgThermalResistanceIcon),
    "resist-kinetic": srcOf(attrDmgKineticResistanceIcon),
    "resist-explosive": srcOf(attrDmgExplosiveResistanceIcon),
    "damage-profile": srcOf(attrWeaponTurretIcon),
    "turret-num": srcOf(weaponTurretNumIcon),
    "launcher-num": srcOf(weaponLauncherNumIcon),
    speed: srcOf(attrSpeedIcon),
    warp: srcOf(attrWarpSpeedIcon),
    "target-range": srcOf(attrTargetRangeIcon),
    "scan-resolution": srcOf(attrScanResolutionIcon),
    "lock-num": srcOf(attrLockNumIcon),
    "sensor-radar": srcOf(attrScanRadarIcon),
    "sensor-ladar": srcOf(attrScanLadarIcon),
    "sensor-magnetometric": srcOf(attrScanMagnetometricIcon),
    "sensor-gravimetric": srcOf(attrScanGravimetricIcon),
    "align-time": srcOf(attrAlignTimeIcon),
    signature: srcOf(attrSignatureRadiusIcon),
    drone: srcOf(attrDroneIcon),
    "drone-range": srcOf(attrDroneRangeIcon),
    mass: srcOf(attrMassIcon),
    cargo: srcOf(attrCargoCapacityIcon),
    "hold-fleet": srcOf(cargoFleetIcon),
    "hold-ship": srcOf(cargoShipIcon),
    "hold-fighter": srcOf(attrWeaponDroneIcon),
    "hold-mining": srcOf(cargoOreIcon),
    "hold-gas": srcOf(cargoGasIcon),
    "hold-mineral": srcOf(cargoMineralIcon),
    "hold-ice": srcOf(cargoIceIcon),
    "hold-command": srcOf(cargoCommandCenterIcon),
    "hold-planetary": srcOf(cargoPlanetaryMaterialsIcon),
    "hold-fuel": srcOf(cargoFuelIcon),
    "hold-ammo": srcOf(attrDamageAlphaIcon),
    "slot-high": srcOf(slotHighIcon),
    "slot-medium": srcOf(slotMediumIcon),
    "slot-low": srcOf(slotLowIcon),
    "slot-rig": srcOf(slotRigIcon),
    "slot-service": srcOf(slotServiceIcon),
    subsystem: srcOf(slotSubsystemIcon),
    "subsystem-core": srcOf(slotSubsystemCoreIcon),
    "subsystem-defensive": srcOf(slotSubsystemDefensiveIcon),
    "subsystem-offensive": srcOf(slotSubsystemOffensiveIcon),
    "subsystem-propulsion": srcOf(slotSubsystemPropulsionIcon),
    "mode-defense": srcOf(tacticalModeDefenseIcon),
    "mode-speed": srcOf(tacticalModeSpeedIcon),
    "mode-target": srcOf(tacticalModeTargetIcon),
    unknown: srcOf(unknownIcon),
} as const satisfies Record<string, string>;

export type EfaIconName = keyof typeof ICONS;
