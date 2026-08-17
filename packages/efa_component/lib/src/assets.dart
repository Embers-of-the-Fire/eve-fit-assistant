import "package:flutter/material.dart";

const String _package = "efa_component";

ImageProvider<Object> _asset(String name) =>
    AssetImage("assets/images/icons/$name", package: _package);

/// Renders a bundled asset image, degrading to a blank box when the asset
/// cannot be loaded (e.g. in widget tests without the package asset bundle).
Widget efaIconImage(ImageProvider<Object> provider, {double? width, double? height}) => Image(
  image: provider,
  width: width,
  height: height,
  errorBuilder: (context, error, stackTrace) => SizedBox(width: width, height: height),
);

/// Bundled slot-chrome and attribute icons shared by EVE Fit Assistant surfaces.
abstract final class EfaAssets {
  static final ImageProvider<Object> unknownIcon = _asset("unknown-icon.png");

  static final ImageProvider<Object> slotHigh = _asset("slot-high.png");
  static final ImageProvider<Object> slotMedium = _asset("slot-medium.png");
  static final ImageProvider<Object> slotLow = _asset("slot-low.png");
  static final ImageProvider<Object> slotRig = _asset("slot-rig.png");
  static final ImageProvider<Object> slotService = _asset("slot-service.png");
  static final ImageProvider<Object> slotSubsystem = _asset("slot-subsystem.png");
  static final ImageProvider<Object> slotSubsystemCore = _asset("slot-subsystem-core.png");
  static final ImageProvider<Object> slotSubsystemDefensive = _asset(
    "slot-subsystem-defensive.png",
  );
  static final ImageProvider<Object> slotSubsystemOffensive = _asset(
    "slot-subsystem-offensive.png",
  );
  static final ImageProvider<Object> slotSubsystemPropulsion = _asset(
    "slot-subsystem-propulsion.png",
  );

  static final ImageProvider<Object> tacticalModeDefense = _asset("tactical-mode-defense.png");
  static final ImageProvider<Object> tacticalModeSpeed = _asset("tactical-mode-speed.png");
  static final ImageProvider<Object> tacticalModeTarget = _asset("tactical-mode-target.png");

  static final ImageProvider<Object> weaponTurretNum = _asset("weapon-turret-num.png");
  static final ImageProvider<Object> weaponLauncherNum = _asset("weapon-launcher-num.png");

  static final ImageProvider<Object> attrCapacitorCharge = _asset("attr-capacitor-charge.png");
  static final ImageProvider<Object> attrDamageAlpha = _asset("attr-damage-alpha.png");
  static final ImageProvider<Object> attrWeaponTurret = _asset("attr-weapon-turret.png");
  static final ImageProvider<Object> attrWeaponDrone = _asset("attr-weapon-drone.png");
  static final ImageProvider<Object> attrCpu = _asset("attr-cpu.png");
  static final ImageProvider<Object> attrPower = _asset("attr-power.png");
  static final ImageProvider<Object> attrRig = _asset("attr-rig.png");

  static final ImageProvider<Object> attrHpShield = _asset("attr-hp-shield.png");
  static final ImageProvider<Object> attrHpArmor = _asset("attr-hp-armor.png");
  static final ImageProvider<Object> attrHpHull = _asset("attr-hp-hull.png");
  static final ImageProvider<Object> attrDmgEmResistance = _asset("attr-dmg-em-resistance.png");
  static final ImageProvider<Object> attrDmgThermalResistance = _asset(
    "attr-dmg-thermal-resistance.png",
  );
  static final ImageProvider<Object> attrDmgKineticResistance = _asset(
    "attr-dmg-kinetic-resistance.png",
  );
  static final ImageProvider<Object> attrDmgExplosiveResistance = _asset(
    "attr-dmg-explosive-resistance.png",
  );

  static final ImageProvider<Object> attrSpeed = _asset("attr-speed.png");
  static final ImageProvider<Object> attrWarpSpeed = _asset("attr-warp-speed.png");
  static final ImageProvider<Object> attrTargetRange = _asset("attr-target-range.png");
  static final ImageProvider<Object> attrScanResolution = _asset("attr-scan-resolution.png");
  static final ImageProvider<Object> attrLockNum = _asset("attr-lock-num.png");
  static final ImageProvider<Object> attrScanRadar = _asset("attr-scan-radar.png");
  static final ImageProvider<Object> attrScanLadar = _asset("attr-scan-ladar.png");
  static final ImageProvider<Object> attrScanMagnetometric = _asset("attr-scan-magnetometric.png");
  static final ImageProvider<Object> attrScanGravimetric = _asset("attr-scan-gravimetric.png");
  static final ImageProvider<Object> attrAlignTime = _asset("attr-align-time.png");
  static final ImageProvider<Object> attrSignatureRadius = _asset("attr-signature-radius.png");
  static final ImageProvider<Object> attrDrone = _asset("attr-drone.png");
  static final ImageProvider<Object> attrDroneRange = _asset("attr-drone-range.png");

  static final ImageProvider<Object> attrMass = _asset("attr-mass.png");
  static final ImageProvider<Object> attrCargoCapacity = _asset("attr-cargo-capacity.png");
  static final ImageProvider<Object> cargoFleet = _asset("cargo-fleet.png");
  static final ImageProvider<Object> cargoShip = _asset("cargo-ship.png");
  static final ImageProvider<Object> cargoOre = _asset("cargo-ore.png");
  static final ImageProvider<Object> cargoGas = _asset("cargo-gas.png");
  static final ImageProvider<Object> cargoMineral = _asset("cargo-mineral.png");
  static final ImageProvider<Object> cargoIce = _asset("cargo-ice.png");
  static final ImageProvider<Object> cargoCommandCenter = _asset("cargo-command-center.png");
  static final ImageProvider<Object> cargoPlanetaryMaterials = _asset(
    "cargo-planetary-materials.png",
  );
  static final ImageProvider<Object> cargoInfrastructure = _asset("cargo-infrastructure.png");
  static final ImageProvider<Object> cargoFuel = _asset("cargo-fuel.png");
}
