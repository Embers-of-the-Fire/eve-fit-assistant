import "package:eve_fit_assistant/storage/fit/schema.dart";

enum DamageProfileName {
  // Groups
  general("通用", "General"),
  frequencyCrystal("频率晶体", "Frequency Crystal"),
  exoticPlasma("异种等离子", "Exotic Plasma Charge"),
  condenserPack("电容包", "Condenser Pack"),
  hybridCharge("混合弹药", "Hybrid Charge"),
  projectileAmmo("射弹弹药", "Projectile Ammo"),
  missile("导弹", "Missile"),
  bomb("炸弹", "Bomb"),

  // General profiles
  uniform("均匀", "Uniform"),
  em("电磁", "EM"),
  thermal("热能", "Thermal"),
  kinetic("动能", "Kinetic"),
  explosive("爆炸", "Explosive"),

  // Frequency Crystals
  aurora("[T2] 极光", "[T2] Aurora"),
  conflagration("[T2] 灼烧", "[T2] Conflagration"),
  radio("射频", "Radio"),
  microwave("微波", "Microwave"),
  infrared("红外", "Infrared"),
  standard("标准", "Standard"),
  ultraviolet("紫外", "Ultraviolet"),
  xray("X射线", "Xray"),
  gamma("伽马", "Gamma"),
  multifrequency("多频", "Multifrequency"),
  gleam("[T2] 微光", "[T2] Gleam"),
  blaze("[T2] 爆燃", "[T2] Blaze"),

  // Exotic Plasma
  mystic("[T2] 奥秘", "[T2] Mystic"),
  meson("介子", "Meson"),
  baryon("重子", "Baryon Exotic Plasma"),
  tetryon("四重子", "Tetryon Exotic Plasma"),
  occult("[T2] 神秘", "[T2] Occult"),

  // Condenser Pack
  strikeSnipe("超级狙击", "StrikeSnipe Ultra"),
  mesmerFlux("梅斯流", "MesmerFlux Condenser Pack"),
  slamBolt("瞬闪", "SlamBolt Condenser Pack"),
  blastShot("爆发", "BlastShot Condenser Pack"),
  galvaSurge("加瓦波", "GalvaSurge Condenser Pack"),
  electroPunch("超级电击", "ElectroPunch Ultra"),

  // Hybrid Charges
  spike("[T2] 钉刺", "[T2] Spike"),
  null_("[T2] 虚空", "[T2] Null"),
  iron("铁质", "Iron Charge"),
  tungsten("钨质", "Tungsten Charge"),
  iridium("铱质", "Iridium Charge"),
  lead("铅质", "Lead Charge"),
  thorium("钍质", "Thorium Charge"),
  plutonium("钼质", "Plutonium Charge"),
  uranium("锰质", "Uranium Charge"),
  antimatter("反物质", "Antimatter Charge"),
  javelin("[T2] 标枪", "[T2] Javelin"),
  void_("[T2] 涅槃", "[T2] Void"),

  // Projectile Ammo
  tremor("[T2] 战栗", "[T2] Tremor"),
  thunderbolt("[T2] 雷暴", "[T2] Barrage"),
  carbonizedLead("碳铅弹", "Carbonized Lead"),
  nuclear("核芯弹", "Nuclear"),
  proton("质子弹", "Proton"),
  depletedUranium("硬钼弹", "Depleted Uranium"),
  titaniumSabot("钛合金萨博弹", "Titanium Sabot"),
  emp("电磁脉冲弹", "EMP"),
  phasedPlasma("定相等离子弹", "Phased Plasma"),
  fusion("聚变弹", "Fusion"),
  quake("[T2] 地震", "[T2] Quake"),
  hail("[T2] 冰雹", "[T2] Hail"),

  // Missiles
  mjolnir("雷神", "Mjolnir Torpedo"),
  inferno("炼狱", "Inferno Torpedo"),
  scourge("鞭挞", "Scourge Rocket"),
  nova("星爆", "Nova Torpedo"),

  // Bombs
  electron("电子", "Electron Bomb"),
  scorch("灼烧", "Scorch Bomb"),
  concussion("震荡", "Concussion Bomb"),
  shrapnel("榴霰", "Shrapnel Bomb");

  const DamageProfileName(this.zh, this.en);
  final String zh;
  final String en;
}

class DamageProfileEntry {
  const DamageProfileEntry(this.name, this.profile);
  final DamageProfileName name;
  final FitDamageProfile profile;
}

class DamageProfileGroup {
  const DamageProfileGroup(this.name, this.entries);
  final DamageProfileName name;
  final List<DamageProfileEntry> entries;
}

const damageProfileCatalog = <DamageProfileGroup>[
  DamageProfileGroup(DamageProfileName.general, [
    DamageProfileEntry(
      DamageProfileName.uniform,
      FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    ),
    DamageProfileEntry(
      DamageProfileName.em,
      FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.thermal,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1),
    ),
    DamageProfileEntry(
      DamageProfileName.kinetic,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.explosive,
      FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.frequencyCrystal, [
    DamageProfileEntry(
      DamageProfileName.aurora,
      FitDamageProfile(em: 0.625, explosive: 0, kinetic: 0, thermal: 0.375),
    ),
    DamageProfileEntry(
      DamageProfileName.conflagration,
      FitDamageProfile(em: 0.8181, explosive: 0, kinetic: 0, thermal: 0.1818),
    ),
    DamageProfileEntry(
      DamageProfileName.radio,
      FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.microwave,
      FitDamageProfile(em: 0.6667, explosive: 0, kinetic: 0, thermal: 0.3333),
    ),
    DamageProfileEntry(
      DamageProfileName.infrared,
      FitDamageProfile(em: 0.7143, explosive: 0, kinetic: 0, thermal: 0.2857),
    ),
    DamageProfileEntry(
      DamageProfileName.standard,
      FitDamageProfile(em: 0.625, explosive: 0, kinetic: 0, thermal: 0.375),
    ),
    DamageProfileEntry(
      DamageProfileName.ultraviolet,
      FitDamageProfile(em: 0.6667, explosive: 0, kinetic: 0, thermal: 0.3333),
    ),
    DamageProfileEntry(
      DamageProfileName.xray,
      FitDamageProfile(em: 0.6, explosive: 0, kinetic: 0, thermal: 0.4),
    ),
    DamageProfileEntry(
      DamageProfileName.gamma,
      FitDamageProfile(em: 0.6364, explosive: 0, kinetic: 0, thermal: 0.3636),
    ),
    DamageProfileEntry(
      DamageProfileName.multifrequency,
      FitDamageProfile(em: 0.5833, explosive: 0, kinetic: 0, thermal: 0.4167),
    ),
    DamageProfileEntry(
      DamageProfileName.gleam,
      FitDamageProfile(em: 0.5, explosive: 0, kinetic: 0, thermal: 0.5),
    ),
    DamageProfileEntry(
      DamageProfileName.blaze,
      FitDamageProfile(em: 0.5, explosive: 0, kinetic: 0, thermal: 0.5),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.exoticPlasma, [
    DamageProfileEntry(
      DamageProfileName.mystic,
      FitDamageProfile(em: 0, explosive: 0.3333, kinetic: 0, thermal: 0.6667),
    ),
    DamageProfileEntry(
      DamageProfileName.meson,
      FitDamageProfile(em: 0, explosive: 0.3864, kinetic: 0, thermal: 0.6136),
    ),
    DamageProfileEntry(
      DamageProfileName.baryon,
      FitDamageProfile(em: 0, explosive: 0.3966, kinetic: 0, thermal: 0.6034),
    ),
    DamageProfileEntry(
      DamageProfileName.tetryon,
      FitDamageProfile(em: 0, explosive: 0.3065, kinetic: 0, thermal: 0.6935),
    ),
    DamageProfileEntry(
      DamageProfileName.occult,
      FitDamageProfile(em: 0, explosive: 0.4156, kinetic: 0, thermal: 0.5844),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.condenserPack, [
    DamageProfileEntry(
      DamageProfileName.strikeSnipe,
      FitDamageProfile(em: 0.5031, explosive: 0, kinetic: 0.4969, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.mesmerFlux,
      FitDamageProfile(em: 0.7267, explosive: 0, kinetic: 0.2733, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.slamBolt,
      FitDamageProfile(em: 0.2688, explosive: 0, kinetic: 0.7312, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.blastShot,
      FitDamageProfile(em: 0.2348, explosive: 0, kinetic: 0.7652, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.galvaSurge,
      FitDamageProfile(em: 0.766, explosive: 0, kinetic: 0.234, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.electroPunch,
      FitDamageProfile(em: 0.5147, explosive: 0, kinetic: 0.4853, thermal: 0),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.hybridCharge, [
    DamageProfileEntry(
      DamageProfileName.spike,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5, thermal: 0.5),
    ),
    DamageProfileEntry(
      DamageProfileName.null_,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.4545, thermal: 0.5455),
    ),
    DamageProfileEntry(
      DamageProfileName.iron,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6, thermal: 0.4),
    ),
    DamageProfileEntry(
      DamageProfileName.tungsten,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6667, thermal: 0.3333),
    ),
    DamageProfileEntry(
      DamageProfileName.iridium,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5714, thermal: 0.4286),
    ),
    DamageProfileEntry(
      DamageProfileName.lead,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.625, thermal: 0.375),
    ),
    DamageProfileEntry(
      DamageProfileName.thorium,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5556, thermal: 0.4444),
    ),
    DamageProfileEntry(
      DamageProfileName.plutonium,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6, thermal: 0.4),
    ),
    DamageProfileEntry(
      DamageProfileName.uranium,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5455, thermal: 0.4545),
    ),
    DamageProfileEntry(
      DamageProfileName.antimatter,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5833, thermal: 0.4167),
    ),
    DamageProfileEntry(
      DamageProfileName.javelin,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.4286, thermal: 0.5714),
    ),
    DamageProfileEntry(
      DamageProfileName.void_,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5, thermal: 0.5),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.projectileAmmo, [
    DamageProfileEntry(
      DamageProfileName.tremor,
      FitDamageProfile(em: 0, explosive: 0.625, kinetic: 0.375, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.thunderbolt,
      FitDamageProfile(em: 0, explosive: 0.5455, kinetic: 0.4545, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.carbonizedLead,
      FitDamageProfile(em: 0, explosive: 0.2, kinetic: 0.8, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.nuclear,
      FitDamageProfile(em: 0, explosive: 0.8, kinetic: 0.2, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.proton,
      FitDamageProfile(em: 0.6, explosive: 0, kinetic: 0.4, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.depletedUranium,
      FitDamageProfile(em: 0, explosive: 0.375, kinetic: 0.25, thermal: 0.375),
    ),
    DamageProfileEntry(
      DamageProfileName.titaniumSabot,
      FitDamageProfile(em: 0, explosive: 0.25, kinetic: 0.75, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.emp,
      FitDamageProfile(em: 0.75, explosive: 0.1667, kinetic: 0.0833, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.phasedPlasma,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0.1667, thermal: 0.8333),
    ),
    DamageProfileEntry(
      DamageProfileName.fusion,
      FitDamageProfile(em: 0, explosive: 0.8333, kinetic: 0.1667, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.quake,
      FitDamageProfile(em: 0, explosive: 0.6429, kinetic: 0.3571, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.hail,
      FitDamageProfile(em: 0, explosive: 0.785, kinetic: 0.215, thermal: 0),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.missile, [
    DamageProfileEntry(
      DamageProfileName.mjolnir,
      FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.inferno,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1),
    ),
    DamageProfileEntry(
      DamageProfileName.scourge,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.nova,
      FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0),
    ),
  ]),
  DamageProfileGroup(DamageProfileName.bomb, [
    DamageProfileEntry(
      DamageProfileName.electron,
      FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.scorch,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1),
    ),
    DamageProfileEntry(
      DamageProfileName.concussion,
      FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0),
    ),
    DamageProfileEntry(
      DamageProfileName.shrapnel,
      FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0),
    ),
  ]),
];
