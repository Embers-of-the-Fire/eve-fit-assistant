enum UnitType {  /// - Name: Length
  /// - Display: m
  /// - Description: 米
  length(1),

  /// - Name: Mass
  /// - Display: kg
  /// - Description: 千克
  mass(2),

  /// - Name: Time
  /// - Display: s
  /// - Description: 秒
  time(3),

  /// - Name: Electric Current
  /// - Display: A
  /// - Description: 安培
  electricCurrent(4),

  /// - Name: Temperature
  /// - Display: K
  /// - Description: 开尔文
  temperature(5),

  /// - Name: Amount Of Substance
  /// - Display: mol
  /// - Description: 摩尔
  amountOfSubstance(6),

  /// - Name: Luminous Intensity
  /// - Display: cd
  /// - Description: 坎德拉
  luminousIntensity(7),

  /// - Name: Area
  /// - Display: m2
  /// - Description: 平方米
  area(8),

  /// - Name: Volume
  /// - Display: m3
  /// - Description: 立方米
  volume(9),

  /// - Name: Speed
  /// - Display: m/s
  /// - Description: 米/秒
  speed(10),

  /// - Name: Acceleration
  /// - Display: m/s
  /// - Description: 米/平方秒
  acceleration(11),

  /// - Name: Wave Number
  /// - Display: m-1
  /// - Description: 米倒数
  waveNumber(12),

  /// - Name: Mass Density
  /// - Display: kg/m3
  /// - Description: 千克/立方米
  massDensity(13),

  /// - Name: Specific Volume
  /// - Display: m3/kg
  /// - Description: 立方米/千克
  specificVolume(14),

  /// - Name: Current Density
  /// - Display: A/m2
  /// - Description: 安培/平方米
  currentDensity(15),

  /// - Name: Magnetic Field Strength
  /// - Display: A/m
  /// - Description: 安培/米
  magneticFieldStrength(16),

  /// - Name: Amount-Of-Substance Concentration
  /// - Display: mol/m3
  /// - Description: 摩尔/立方米
  amountOfSubstanceConcentration(17),

  /// - Name: Luminance
  /// - Display: cd/m2
  /// - Description: 坎德拉/平方米
  luminance(18),

  /// - Name: Mass Fraction
  /// - Display: kg/kg = 1
  /// - Description: 千克/千克，可用数字1表示
  massFraction(19),

  /// - Name: Milliseconds
  /// - Display: s
  /// - Description: 
  milliseconds(101),

  /// - Name: Millimeters
  /// - Display: mm
  /// - Description: 
  millimeters(102),

  /// - Name: MegaPascals
  /// - Display: 
  /// - Description: 
  megaPascals(103),

  /// - Name: Multiplier
  /// - Display: x
  /// - Description: 表明该单位是乘数。
  multiplier(104),

  /// - Name: Percentage
  /// - Display: %
  /// - Description: 
  percentage(105),

  /// - Name: Teraflops
  /// - Display: tf
  /// - Description: 
  teraflops(106),

  /// - Name: MegaWatts
  /// - Display: MW
  /// - Description: 
  megaWatts(107),

  /// - Name: Inverse Absolute Percent
  /// - Display: %
  /// - Description: 用于抗性。0.0 = 100% 1.0 = 0%
  inverseAbsolutePercent(108),

  /// - Name: Modifier Percent
  /// - Display: %
  /// - Description: 用于乘数，显示为 %1.1 = +10%0.9 = -10%
  modifierPercent(109),

  /// - Name: Inversed Modifier Percent
  /// - Display: %
  /// - Description: 用来调整伤害抗性。伤害抗性加成。0.1 = 90% 0.9 = 10%
  inversedModifierPercent(111),

  /// - Name: Radians/Second
  /// - Display: r/s
  /// - Description: 转速。
  radiansPerSecond(112),

  /// - Name: Hitpoints
  /// - Display: HP
  /// - Description: 
  hitpoints(113),

  /// - Name: capacitor units
  /// - Display: GJ
  /// - Description: 千兆焦耳
  capacitorUnits(114),

  /// - Name: groupID
  /// - Display: 组别ID
  /// - Description: 
  groupId(115),

  /// - Name: typeID
  /// - Display: 类别ID
  /// - Description: 
  typeId(116),

  /// - Name: Sizeclass
  /// - Display: 1=小型  2=中型  3=大型
  /// - Description: 1=小型 2=中型 3=大型 4=超大型
  sizeclass(117),

  /// - Name: Ore units
  /// - Display: 矿石单位
  /// - Description: 
  oreUnits(118),

  /// - Name: attributeID
  /// - Display: 属性ID
  /// - Description: 
  attributeId(119),

  /// - Name: attributePoints
  /// - Display: 点
  /// - Description: 
  attributePoints(120),

  /// - Name: realPercent
  /// - Display: %
  /// - Description: 用于真实百分比，比如数字5表示5%
  realPercent(121),

  /// - Name: Fitting slots
  /// - Display: 
  /// - Description: 
  fittingSlots(122),

  /// - Name: trueTime
  /// - Display: s
  /// - Description: 直接显示秒
  trueTime(123),

  /// - Name: Modifier Relative Percent
  /// - Display: %
  /// - Description: 用于相对百分比，显示为 %
  modifierRelativePercent(124),

  /// - Name: Newton
  /// - Display: N
  /// - Description: 
  newton(125),

  /// - Name: Light Year
  /// - Display: 光年
  /// - Description: 
  lightYear(126),

  /// - Name: Absolute Percent
  /// - Display: %
  /// - Description: 0.0 = 0% 1.0 = 100%
  absolutePercent(127),

  /// - Name: Drone bandwidth
  /// - Display: Mbit/s
  /// - Description: 兆比特/秒
  droneBandwidth(128),

  /// - Name: Hours
  /// - Display: 
  /// - Description: 小时
  hours(129),

  /// - Name: Money
  /// - Display: 星币
  /// - Description: 星币
  money(133),

  /// - Name: Logistical Capacity
  /// - Display: 立方米/时
  /// - Description: 行星互动的带宽
  logisticalCapacity(134),

  /// - Name: Astronomical Unit
  /// - Display: AU
  /// - Description: 表示距离，1AU等于地球到太阳的距离。
  astronomicalUnit(135),

  /// - Name: Slot
  /// - Display: 槽位
  /// - Description: 用于多种场合的槽位数字前缀
  slot(136),

  /// - Name: Boolean
  /// - Display: 1=True 0=False
  /// - Description: 用于显示布尔标记 1=True 0=False
  boolean(137),

  /// - Name: Units
  /// - Display: 单位
  /// - Description: 某样物品的单位，比如燃料
  units(138),

  /// - Name: Bonus
  /// - Display: +
  /// - Description: 用于正值的加号
  bonus(139),

  /// - Name: Level
  /// - Display: 等级
  /// - Description: 用于那些以等级划分的事物
  level(140),

  /// - Name: Hardpoints
  /// - Display: 安装座
  /// - Description: 用于各种炮塔、发射器以及改装件的装配点数量
  hardpoints(141),

  /// - Name: Sex
  /// - Display: 1=男性 2=中性 3=女性
  /// - Description: 
  sex(142),

  /// - Name: Datetime
  /// - Display: 
  /// - Description: 日期和时间
  datetime(143),

  /// - Name: Warp speed
  /// - Display: AU/s
  /// - Description: AU每秒
  warpSpeed(144),

  /// - Name: modifier realPercent
  /// - Display: %
  /// - Description: 用于乘数，显示为 % 10 is +10% -10 is -10% 3.6 is +3.6%
  modifierRealPercent(205),

  ;

  final int id;

  const UnitType(this.id);

  static UnitType? fromID(int id) => switch (id) {
    1 => UnitType.length,
    2 => UnitType.mass,
    3 => UnitType.time,
    4 => UnitType.electricCurrent,
    5 => UnitType.temperature,
    6 => UnitType.amountOfSubstance,
    7 => UnitType.luminousIntensity,
    8 => UnitType.area,
    9 => UnitType.volume,
    10 => UnitType.speed,
    11 => UnitType.acceleration,
    12 => UnitType.waveNumber,
    13 => UnitType.massDensity,
    14 => UnitType.specificVolume,
    15 => UnitType.currentDensity,
    16 => UnitType.magneticFieldStrength,
    17 => UnitType.amountOfSubstanceConcentration,
    18 => UnitType.luminance,
    19 => UnitType.massFraction,
    101 => UnitType.milliseconds,
    102 => UnitType.millimeters,
    103 => UnitType.megaPascals,
    104 => UnitType.multiplier,
    105 => UnitType.percentage,
    106 => UnitType.teraflops,
    107 => UnitType.megaWatts,
    108 => UnitType.inverseAbsolutePercent,
    109 => UnitType.modifierPercent,
    111 => UnitType.inversedModifierPercent,
    112 => UnitType.radiansPerSecond,
    113 => UnitType.hitpoints,
    114 => UnitType.capacitorUnits,
    115 => UnitType.groupId,
    116 => UnitType.typeId,
    117 => UnitType.sizeclass,
    118 => UnitType.oreUnits,
    119 => UnitType.attributeId,
    120 => UnitType.attributePoints,
    121 => UnitType.realPercent,
    122 => UnitType.fittingSlots,
    123 => UnitType.trueTime,
    124 => UnitType.modifierRelativePercent,
    125 => UnitType.newton,
    126 => UnitType.lightYear,
    127 => UnitType.absolutePercent,
    128 => UnitType.droneBandwidth,
    129 => UnitType.hours,
    133 => UnitType.money,
    134 => UnitType.logisticalCapacity,
    135 => UnitType.astronomicalUnit,
    136 => UnitType.slot,
    137 => UnitType.boolean,
    138 => UnitType.units,
    139 => UnitType.bonus,
    140 => UnitType.level,
    141 => UnitType.hardpoints,
    142 => UnitType.sex,
    143 => UnitType.datetime,
    144 => UnitType.warpSpeed,
    205 => UnitType.modifierRealPercent,
    _ => null,
  };
}
