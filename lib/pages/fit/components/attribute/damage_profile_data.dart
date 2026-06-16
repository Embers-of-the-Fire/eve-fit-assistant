import "package:eve_fit_assistant/storage/fit/schema.dart";

class DamageProfileEntry {
  const DamageProfileEntry(this.name, this.profile);
  final String name;
  final FitDamageProfile profile;
}

class DamageProfileGroup {
  const DamageProfileGroup(this.name, this.entries);
  final String name;
  final List<DamageProfileEntry> entries;
}

const damageProfileCatalog = <DamageProfileGroup>[
  DamageProfileGroup("通用", [
    DamageProfileEntry("均匀", FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25)),
    DamageProfileEntry("电磁", FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0)),
    DamageProfileEntry("热能", FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1)),
    DamageProfileEntry("动能", FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0)),
    DamageProfileEntry("爆炸", FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0)),
  ]),
  DamageProfileGroup("频率晶体", [
    DamageProfileEntry("[T2] 极光", FitDamageProfile(em: 0.625, explosive: 0, kinetic: 0, thermal: 0.375)),
    DamageProfileEntry("[T2] 灼烧", FitDamageProfile(em: 0.8181, explosive: 0, kinetic: 0, thermal: 0.1818)),
    DamageProfileEntry("射频", FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0)),
    DamageProfileEntry("微波", FitDamageProfile(em: 0.6667, explosive: 0, kinetic: 0, thermal: 0.3333)),
    DamageProfileEntry("红外", FitDamageProfile(em: 0.7143, explosive: 0, kinetic: 0, thermal: 0.2857)),
    DamageProfileEntry("标准", FitDamageProfile(em: 0.625, explosive: 0, kinetic: 0, thermal: 0.375)),
    DamageProfileEntry("紫外", FitDamageProfile(em: 0.6667, explosive: 0, kinetic: 0, thermal: 0.3333)),
    DamageProfileEntry("X射线", FitDamageProfile(em: 0.6, explosive: 0, kinetic: 0, thermal: 0.4)),
    DamageProfileEntry("伽马", FitDamageProfile(em: 0.6364, explosive: 0, kinetic: 0, thermal: 0.3636)),
    DamageProfileEntry("多频", FitDamageProfile(em: 0.5833, explosive: 0, kinetic: 0, thermal: 0.4167)),
    DamageProfileEntry("[T2] 微光", FitDamageProfile(em: 0.5, explosive: 0, kinetic: 0, thermal: 0.5)),
    DamageProfileEntry("[T2] 爆燃", FitDamageProfile(em: 0.5, explosive: 0, kinetic: 0, thermal: 0.5)),
  ]),
  DamageProfileGroup("异种等离子", [
    DamageProfileEntry("[T2] 奥秘", FitDamageProfile(em: 0, explosive: 0.3333, kinetic: 0, thermal: 0.6667)),
    DamageProfileEntry("介子", FitDamageProfile(em: 0, explosive: 0.3864, kinetic: 0, thermal: 0.6136)),
    DamageProfileEntry("重子", FitDamageProfile(em: 0, explosive: 0.3966, kinetic: 0, thermal: 0.6034)),
    DamageProfileEntry("四重子", FitDamageProfile(em: 0, explosive: 0.3065, kinetic: 0, thermal: 0.6935)),
    DamageProfileEntry("[T2] 神秘", FitDamageProfile(em: 0, explosive: 0.4156, kinetic: 0, thermal: 0.5844)),
  ]),
  DamageProfileGroup("电容包", [
    DamageProfileEntry("超级狙击", FitDamageProfile(em: 0.5031, explosive: 0, kinetic: 0.4969, thermal: 0)),
    DamageProfileEntry("梅斯流", FitDamageProfile(em: 0.7267, explosive: 0, kinetic: 0.2733, thermal: 0)),
    DamageProfileEntry("瞬闪", FitDamageProfile(em: 0.2688, explosive: 0, kinetic: 0.7312, thermal: 0)),
    DamageProfileEntry("爆发", FitDamageProfile(em: 0.2348, explosive: 0, kinetic: 0.7652, thermal: 0)),
    DamageProfileEntry("加瓦波", FitDamageProfile(em: 0.766, explosive: 0, kinetic: 0.234, thermal: 0)),
    DamageProfileEntry("超级电击", FitDamageProfile(em: 0.5147, explosive: 0, kinetic: 0.4853, thermal: 0)),
  ]),
  DamageProfileGroup("混合弹药", [
    DamageProfileEntry("[T2] 钉刺", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5, thermal: 0.5)),
    DamageProfileEntry("[T2] 虚空", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.4545, thermal: 0.5455)),
    DamageProfileEntry("铁质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6, thermal: 0.4)),
    DamageProfileEntry("钨质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6667, thermal: 0.3333)),
    DamageProfileEntry("铱质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5714, thermal: 0.4286)),
    DamageProfileEntry("铅质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.625, thermal: 0.375)),
    DamageProfileEntry("钍质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5556, thermal: 0.4444)),
    DamageProfileEntry("钼质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.6, thermal: 0.4)),
    DamageProfileEntry("锰质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5455, thermal: 0.4545)),
    DamageProfileEntry("反物质", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5833, thermal: 0.4167)),
    DamageProfileEntry("[T2] 标枪", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.4286, thermal: 0.5714)),
    DamageProfileEntry("[T2] 涅槃", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.5, thermal: 0.5)),
  ]),
  DamageProfileGroup("射弹弹药", [
    DamageProfileEntry("[T2] 战栗", FitDamageProfile(em: 0, explosive: 0.625, kinetic: 0.375, thermal: 0)),
    DamageProfileEntry("[T2] 雷暴", FitDamageProfile(em: 0, explosive: 0.5455, kinetic: 0.4545, thermal: 0)),
    DamageProfileEntry("碳铅弹", FitDamageProfile(em: 0, explosive: 0.2, kinetic: 0.8, thermal: 0)),
    DamageProfileEntry("核芯弹", FitDamageProfile(em: 0, explosive: 0.8, kinetic: 0.2, thermal: 0)),
    DamageProfileEntry("质子弹", FitDamageProfile(em: 0.6, explosive: 0, kinetic: 0.4, thermal: 0)),
    DamageProfileEntry("硬钼弹", FitDamageProfile(em: 0, explosive: 0.375, kinetic: 0.25, thermal: 0.375)),
    DamageProfileEntry("钛合金萨博弹", FitDamageProfile(em: 0, explosive: 0.25, kinetic: 0.75, thermal: 0)),
    DamageProfileEntry("电磁脉冲弹", FitDamageProfile(em: 0.75, explosive: 0.1667, kinetic: 0.0833, thermal: 0)),
    DamageProfileEntry("定相等离子弹", FitDamageProfile(em: 0, explosive: 0, kinetic: 0.1667, thermal: 0.8333)),
    DamageProfileEntry("聚变弹", FitDamageProfile(em: 0, explosive: 0.8333, kinetic: 0.1667, thermal: 0)),
    DamageProfileEntry("[T2] 地震", FitDamageProfile(em: 0, explosive: 0.6429, kinetic: 0.3571, thermal: 0)),
    DamageProfileEntry("[T2] 冰雹", FitDamageProfile(em: 0, explosive: 0.785, kinetic: 0.215, thermal: 0)),
  ]),
  DamageProfileGroup("导弹", [
    DamageProfileEntry("雷神", FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0)),
    DamageProfileEntry("炼狱", FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1)),
    DamageProfileEntry("鞭挞", FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0)),
    DamageProfileEntry("星爆", FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0)),
  ]),
  DamageProfileGroup("炸弹", [
    DamageProfileEntry("电子", FitDamageProfile(em: 1, explosive: 0, kinetic: 0, thermal: 0)),
    DamageProfileEntry("灼烧", FitDamageProfile(em: 0, explosive: 0, kinetic: 0, thermal: 1)),
    DamageProfileEntry("震荡", FitDamageProfile(em: 0, explosive: 0, kinetic: 1, thermal: 0)),
    DamageProfileEntry("榴霰", FitDamageProfile(em: 0, explosive: 1, kinetic: 0, thermal: 0)),
  ]),
];
