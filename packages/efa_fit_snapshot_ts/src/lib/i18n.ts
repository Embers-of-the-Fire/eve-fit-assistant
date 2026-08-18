const en = {
    fitPageTitle: "{fitName} - {shipName}",
    highSlot: "High Slot",
    midSlot: "Mid Slot",
    lowSlot: "Low Slot",
    rigSlot: "Rig Slot",
    subsystemSlot: "Subsystem",
    serviceSlot: "Service Slot",
    tacticalMode: "Tactical Mode",
    implantSlot: "Implant",
    boosterSlot: "Booster",
    drone: "Drone",
    fighter: "Fighter",
    slotEmpty: "{slotName} (Empty)",
    skillProfileAll5: "All 5",
    skillProfileAll0: "All 0",
    skillProfileAlphaMax: "Alpha Max",
    fighterAbilityTurret: "Turret",
    fighterAbilityMissiles: "Missiles",
    fighterAbilityAttackMissiles: "Attack Missiles",
    fighterAbilityBomb: "Bomb",
    capacitorStable: "{percent}% Stable",
    capacitorUnstable: "Unstable",
} as const;

const zh: Record<keyof typeof en, string> = {
    fitPageTitle: "{fitName} - {shipName}",
    highSlot: "高能量槽",
    midSlot: "中能量槽",
    lowSlot: "低能量槽",
    rigSlot: "改装件槽",
    subsystemSlot: "子系统",
    serviceSlot: "服务设施槽",
    tacticalMode: "战术模式",
    implantSlot: "植入体槽",
    boosterSlot: "增效剂槽",
    drone: "无人机",
    fighter: "铁骑舰载机",
    slotEmpty: "{slotName}（空）",
    skillProfileAll5: "全 5",
    skillProfileAll0: "全 0",
    skillProfileAlphaMax: "Alpha 最高",
    fighterAbilityTurret: "炮台",
    fighterAbilityMissiles: "导弹",
    fighterAbilityAttackMissiles: "攻击导弹",
    fighterAbilityBomb: "炸弹",
    capacitorStable: "{percent}% 稳定",
    capacitorUnstable: "不稳定",
};

export type SnapshotMessageKey = keyof typeof en;

export type SnapshotMessages = Record<SnapshotMessageKey, string>;

/**
 * Bundled translation tables keyed by BCP-47 locale. Consumers may register
 * additional tables at runtime via {@link registerSnapshotLocale}.
 */
const tables: Record<string, SnapshotMessages> = { en, zh };

export function registerSnapshotLocale(locale: string, messages: SnapshotMessages): void {
    tables[locale] = messages;
}

export type SnapshotTranslateParams = Record<string, string | number>;

/**
 * Translates a component message for the given BCP-47 locale.
 *
 * Resolution order: exact language tag → language code → `"en"`. `{name}`
 * placeholders are substituted from `params`.
 */
export function translateSnapshot(
    locale: string,
    key: SnapshotMessageKey,
    params?: SnapshotTranslateParams,
): string {
    const language = locale.split("-")[0]?.toLowerCase() ?? "en";
    const template = tables[locale]?.[key] ?? tables[language]?.[key] ?? en[key];
    if (!params) return template;
    return template.replace(/\{(\w+)\}/g, (match, name: string) =>
        name in params ? String(params[name]) : match,
    );
}

/**
 * Resolves a display name from a snapshot `names` map (BCP-47 keyed).
 *
 * Order: exact language tag → language code → `"en"` → first entry.
 */
export function resolveSnapshotName(names: Record<string, string>, locale: string): string {
    const keys = Object.keys(names);
    if (keys.length === 0) return "";
    if (names[locale] !== undefined) return names[locale];
    const language = locale.split("-")[0]?.toLowerCase() ?? "en";
    if (names[language] !== undefined) return names[language];
    if (names.en !== undefined) return names.en;
    return names[keys[0]];
}
