/**
 * Inline SVG glyphs standing in for the app's bundled `EfaAssets` icon sheets.
 * Each entry is inner markup for a 24x24, stroke-based (currentColor) icon.
 */
export const GLYPHS = {
    person: '<circle cx="12" cy="8" r="4"/><path d="M5 21c0-4 3-7 7-7s7 3 7 7"/>',
    implant: '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
    unknown:
        '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 0 1 5 .5c0 1.5-2.5 2-2.5 3.5"/><circle cx="12" cy="17" r="0.6" fill="currentColor"/>',

    "slot-high": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M8 15l4-6 4 6z"/>',
    "slot-medium": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M8 12h8"/>',
    "slot-low": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M8 9l4 6 4-6z"/>',
    "slot-rig": '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M12 7l5 5-5 5-5-5z"/>',
    "slot-service":
        '<rect x="3" y="3" width="18" height="18" rx="2"/><circle cx="12" cy="12" r="3"/><path d="M12 6v2M12 16v2M6 12h2M16 12h2"/>',

    subsystem: '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9Z"/>',
    "subsystem-core": '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9Z"/><circle cx="12" cy="12" r="2"/>',
    "subsystem-defensive":
        '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9Z"/><path d="M12 8l3.5 1.5v2.5c0 2.5-1.5 4-3.5 5-2-1-3.5-2.5-3.5-5V9.5Z"/>',
    "subsystem-offensive":
        '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9Z"/><circle cx="12" cy="12" r="2.5"/><path d="M12 7v2M12 15v2M7 12h2M15 12h2"/>',
    "subsystem-propulsion":
        '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9Z"/><path d="M8 12h7M12 8.5L15.5 12 12 15.5"/>',

    "mode-defense":
        '<path d="M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6Z"/><path d="M9 11.5l2 2 4-4"/>',
    "mode-speed": '<path d="M5 6l6 6-6 6M13 6l6 6-6 6"/>',
    "mode-target": '<circle cx="12" cy="12" r="6"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',

    capacitor: '<path fill="currentColor" stroke="none" d="M13 2 5 14h6l-2 8L19 9h-6Z"/>',
    alpha: '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
    cpu: '<rect x="7" y="7" width="10" height="10" rx="1"/><rect x="10.5" y="10.5" width="3" height="3"/><path d="M9 7V4M12 7V4M15 7V4M9 20v-3M12 20v-3M15 20v-3M7 9H4M7 12H4M7 15H4M20 9h-3M20 12h-3M20 15h-3"/>',
    power: '<circle cx="12" cy="12" r="9"/><path fill="currentColor" stroke="none" d="M12.8 6.5 9.2 13h2.6l-1.3 4.5L14.4 11h-2.6Z"/>',
    rig: '<path d="M12 3l9 9-9 9-9-9Z"/><path d="M12 8l4 4-4 4-4-4Z"/>',
    "drone-bandwidth":
        '<circle cx="6" cy="6" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 8l8 8M16 8l-8 8"/>',

    "hp-shield":
        '<path d="M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6Z"/><path d="M8.5 11.5a3.5 3.5 0 0 1 7 0"/>',
    "hp-armor": '<path d="M5 8l7-3 7 3M5 13l7-3 7 3M5 18l7-3 7 3"/>',
    "hp-hull": '<path d="M12 3l6 18H6Z"/><path d="M12 8v6"/>',

    turret: '<path d="M3 15h11"/><rect x="14" y="11" width="6" height="8" rx="1"/><path d="M9 21h11"/>',
    launcher:
        '<path d="M7 21V9M12 21V9M17 21V9"/><path d="M7 9L5.5 5 7 3l1.5 2Z"/><path d="M12 9l-1.5-4L12 3l1.5 2Z"/><path d="M17 9l-1.5-4L17 3l1.5 2Z"/>',

    speed: '<path d="M5 6l6 6-6 6M13 6l6 6-6 6"/>',
    warp: '<path d="M3 12h10M5 6.5l9 4M5 17.5l9-4"/><circle cx="17.5" cy="12" r="2.5"/>',
    "target-range":
        '<circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',
    "scan-resolution":
        '<path d="M4.5 19a8.5 8.5 0 0 1 15 0M8 19a4.5 4.5 0 0 1 8 0"/><path d="M12 19l4.5-9"/><circle cx="12" cy="19" r="1" fill="currentColor" stroke="none"/>',
    "lock-num":
        '<path d="M8 4H4v16h4M16 4h4v16h-4"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/>',

    "sensor-radar":
        '<path d="M6 15a7 7 0 0 1 12 0"/><path d="M12 15l5-9"/><circle cx="12" cy="15" r="1" fill="currentColor" stroke="none"/>',
    "sensor-ladar": '<path d="M3 12c2-6 4-6 6 0s4 6 6 0 4-6 6 0"/>',
    "sensor-magnetometric": '<path d="M7 3v8a5 5 0 0 0 10 0V3"/><path d="M7 8h4M13 8h4"/>',
    "sensor-gravimetric":
        '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="9.5"/>',

    "align-time": '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    signature: '<circle cx="12" cy="12" r="4"/><circle cx="12" cy="12" r="8"/>',
    drone: '<circle cx="6" cy="6" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 8l8 8M16 8l-8 8"/>',
    "drone-range":
        '<circle cx="6" cy="6" r="2"/><circle cx="18" cy="6" r="2"/><circle cx="6" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><path d="M8 8l8 8M16 8l-8 8"/><path d="M3 12a9 9 0 0 1 9-9M21 12a9 9 0 0 1-9 9"/>',
    mass: '<circle cx="12" cy="15" r="6"/><path d="M9.5 9.5a3 3 0 0 1 5 0"/>',
    cargo: '<path d="M4 8l8-4 8 4v8l-8 4-8-4Z"/><path d="M4 8l8 4 8-4M12 12v8"/>',

    "hold-fleet": '<path d="M3 10l6-3 6 3v6l-6 3-6-3Z"/><path d="M15 10l6-3v6"/>',
    "hold-ship": '<path d="M12 3v3M4 16l8-10 8 10"/><path d="M4 16c2.5 3 13.5 3 16 0"/>',
    "hold-fighter": '<path d="M3 11L21 3l-7 18-3-7Z"/><path d="M11 14L21 3"/>',
    "hold-mining": '<path d="M5 20L14 10"/><path d="M8 5c4-2.5 9-1.5 11.5 2.5"/>',
    "hold-gas": '<path d="M7 18a4 4 0 0 1-.5-7.97A5 5 0 0 1 16 8.5 3.75 3.75 0 0 1 18 18Z"/>',
    "hold-mineral": '<path d="M7 4h10l4 5-9 11L3 9Z"/><path d="M3 9h18M9 4l3 5 3-5"/>',
    "hold-ice": '<path d="M12 2v20M4.5 6l15 12M19.5 6l-15 12"/>',
    "hold-command":
        '<path d="M12 3l7 3v5c0 5-3 8.5-7 10-4-1.5-7-5-7-10V6Z"/><path fill="currentColor" stroke="none" d="M12 8l1.1 2.3 2.5.4-1.8 1.8.4 2.5-2.2-1.2-2.2 1.2.4-2.5-1.8-1.8 2.5-.4Z"/>',
    "hold-planetary":
        '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3.2 3.2 3.2 14.8 0 18-3.2-3.2-3.2-14.8 0-18"/>',
    "hold-fuel": '<path d="M12 3C8.5 9 6.5 12 6.5 15a5.5 5.5 0 0 0 11 0C17.5 12 15.5 9 12 3Z"/>',
    "hold-ammo": '<path d="M9 21h6v-8a3 3 0 0 0-6 0Z"/><path d="M9 17h6"/>',

    "resist-em": '<path fill="currentColor" stroke="none" d="M13 2 5 14h6l-2 8L19 9h-6Z"/>',
    "resist-thermal":
        '<path d="M12 3C9 7 6.5 9.5 6.5 13a5.5 5.5 0 0 0 11 0C17.5 9.5 15 7 12 3Z"/><path d="M12 21a3 3 0 0 1-3-3c0-1.5 1.2-2.6 3-4.5 1.8 1.9 3 3 3 4.5a3 3 0 0 1-3 3Z"/>',
    "resist-kinetic": '<path d="M12 4l8 8-8 8-8-8Z"/><circle cx="12" cy="12" r="2"/>',
    "resist-explosive":
        '<path d="M12 2l1.8 5.6L19 5l-3.4 4.8L21 12l-5.4 2.2L19 19l-5.2-2.6L12 22l-1.8-5.6L5 19l3.4-4.8L3 12l5.4-2.2L5 5l5.2 2.6Z"/>',
} as const satisfies Record<string, string>;

export type GlyphName = keyof typeof GLYPHS;
