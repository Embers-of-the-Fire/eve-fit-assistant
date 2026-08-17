# efa_fit

Pure-Dart fit format logic for EVE Fit Assistant:

- **EFA(n) native payloads** — versioned JSON envelope → gzip → base64/base64url,
  with the `EFA<n>:` prefix and size caps.
- **EFT-compatible text** — `parseEft`/`formatEft` over the neutral `EftFit` model,
  with an injected `EftTypeResolver`/`EftTypeNameLookup` for name/slot resolution.
- **Fit links** — `buildFitLinkShareUrl`, `parseFitLinkUri`, `parseFitLinkBootUri`.

## Fit snapshots

`FitSnapshot` (`data/schema/fit_snapshot.proto`) is a self-contained protobuf
rendering of a fit page. Unlike the stored fit (which carries bare type IDs and
resolves names, icons, slot layout and statistics through the checkout resource
schema), a snapshot bakes everything in:

- localized names per entity (`names["en"]` is always present),
- icon hints plus the `type_id` itself, which doubles as a public image-CDN key
  (e.g. the EVE image server `types/{type_id}/icon`) — no image registry needed,
- the ship's slot layout, so empty slots and hardpoint counters render directly,
- pre-formatted statistics strings/figures from the fitting engine — no engine,
  localization database, or checkout needed downstream.

Consumers render the snapshot verbatim; producers resolve everything at snapshot
time. Rack lists have exactly the ship's slot count; entries without `item` are
empty slots.

### Building a snapshot

`FitSnapshotBuilder` (`lib/src/snapshot.dart`) assembles a `FitSnapshot` from
neutral, immutable `Snapshot*Data` values and enforces the schema invariants:
racks are auto-sized from the ship layout (unset slots become empty entries),
all ten implant slots are emitted, slot indexes are bounds-checked, every
displayable type must carry an `en` name, and the schema version plus creation
timestamp are stamped automatically. `encodeFitSnapshot`/`decodeFitSnapshot`
handle the wire format and version check.

```dart
final builder = FitSnapshotBuilder(
  fitName: "Brawler Vexor",
  ship: const SnapshotTypeData(typeId: 634, names: {"en": "Vexor", "zh": "狂怒者级"}),
  layout: const SnapshotShipLayoutData(
    highSlots: 5, mediumSlots: 3, lowSlots: 4, rigSlots: 3, turretHardpoints: 4,
  ),
  character: const SnapshotCharacterData.builtin(SnapshotBuiltinCharacter.all5,
      names: {"en": "All 5"}),
  damageProfile: const SnapshotDamageProfile.uniform(),
  lastModified: DateTime.fromMillisecondsSinceEpoch(1755201600000),
);

builder.setModule(
  SnapshotRack.high,
  0,
  const SnapshotModuleData(
    type: SnapshotTypeData(typeId: 3170, names: {"en": "Heavy Electron Blaster II"}),
    state: Slots_SlotState.ACTIVE,
    charge: SnapshotChargeData(
      type: SnapshotTypeData(typeId: 222, names: {"en": "Void S"}),
      quantity: 8,
    ),
    isTurret: true,
    relatedValues: [SnapshotDisplayValueData(text: "86.4 DPS", attributeId: 64)],
  ),
);
builder.addDrone(const SnapshotDroneData(
  type: SnapshotTypeData(typeId: 2188, names: {"en": "Hammerhead II"}),
  state: Slots_SlotState.ACTIVE,
  quantity: 5,
));

final FitSnapshot snapshot = builder.build();
final bytes = encodeFitSnapshot(snapshot);
```

### Example

A Vexor drone-brawler fit, in protobuf text format (type IDs are illustrative):

```proto
# fit_snapshot.proto — FitSnapshot
version: 1

header {
  fit_name: "Brawler Vexor"
  description: "Dual-rep brawler, scram/web range control."
  last_modified_ms: 1755201600000
  created_at_ms: 1755300000000
  generator: "eve-fit-assistant/0.6.0"
  checkout_id: "a1b2c3d4"   # provenance only; never required for rendering
  server_id: "tranquility"
}

ship {
  type {
    type_id: 634
    names: { key: "en" value: "Vexor" }
    names: { key: "zh" value: "狂怒者级" }
    icon { icon_id: 1437 }
    meta_group {
      meta_group_id: 1
      names: { key: "en" value: "Tech I" }
      icon { icon_id: 803 }
    }
  }
  layout {
    high_slots: 5
    medium_slots: 3
    low_slots: 4
    rig_slots: 3
    subsystem_slots: 0
    service_slots: 0
    turret_hardpoints: 4
    launcher_hardpoints: 1
    fighter_tubes: 0
  }
}

high_slots {
  index: 0
  item {
    type {
      type_id: 3170
      names: { key: "en" value: "Heavy Electron Blaster II" }
      icon { icon_id: 2425 }
      meta_group { meta_group_id: 2 names: { key: "en" value: "Tech II" } }
    }
    state: ACTIVE
    charge {
      type {
        type_id: 222
        names: { key: "en" value: "Void S" }
        icon { icon_id: 1282 }
      }
      quantity: 8   # chargeAmount: the "8 x" prefix of the charge row
    }
    is_turret: true
    related_values { attribute_id: 64 icon { icon_id: 3473 } text: "86.4 DPS" }
  }
}
# ... indexes 1..3 repeat the same blaster; hardpoint counter shows 4/4 ...
high_slots { index: 4 }   # empty slot row, trailing label "5"

medium_slots {
  index: 0
  item {
    type {
      type_id: 438
      names: { key: "en" value: "10MN Afterburner II" }
      icon { icon_id: 2456 }
    }
    state: ACTIVE
  }
}
medium_slots {
  index: 1
  item {
    type {
      type_id: 5946
      names: { key: "en" value: "Warp Scrambler II" }
    }
    state: ACTIVE
  }
}
medium_slots {
  index: 2
  item {
    type {
      type_id: 527
      names: { key: "en" value: "Stasis Webifier II" }
    }
    state: ACTIVE
  }
}

low_slots {
  index: 0
  item {
    type {
      type_id: 10190
      names: { key: "en" value: "Damage Control II" }
    }
    state: ONLINE
  }
}
low_slots {
  index: 1
  item {
    type {
      type_id: 41211
      names: { key: "en" value: "Medium Ancillary Armor Repairer" }
    }
    state: ACTIVE
    charge {
      type { type_id: 28668 names: { key: "en" value: "Nanite Repair Paste" } }
      quantity: 32
    }
  }
}
low_slots { index: 2 }   # empty
low_slots { index: 3 }   # empty

rig_slots {
  index: 0
  item {
    type {
      type_id: 31087
      names: { key: "en" value: "Medium Auxiliary Nano Pump I" }
    }
    state: PASSIVE
  }
}
rig_slots { index: 1 }
rig_slots { index: 2 }

drones {
  type {
    type_id: 2188
    names: { key: "en" value: "Hammerhead II" }
  }
  state: ACTIVE
  quantity: 5
}
drones {
  type { type_id: 2454 names: { key: "en" value: "Hobgoblin II" } }
  state: PASSIVE
  quantity: 5
}

implants {
  slot_index: 7
  item {
    type { type_id: 22107 names: { key: "en" value: "Zainou 'Deadeye' Small Hybrid Turret SH-705" } }
    state: ONLINE
  }
}
implants { slot_index: 8 }   # empty; slots 1..6, 9, 10 likewise (omitted)

boosters {
  slot_index: 1
  type { type_id: 28679 names: { key: "en" value: "Standard Exile Booster" } }
  state: ONLINE
}

character {
  builtin: ALL_5
  names: { key: "en" value: "All 5" }
  names: { key: "zh" value: "全 5" }
}

damage_profile { em: 0.25 thermal: 0.25 kinetic: 0.25 explosive: 0.25 }

statistics {
  capacitor {
    is_stable: true
    stable_fraction: 0.34
    peak_use_rate: 22.4
    peak_recharge_rate: 31.8
    capacity_gj: 1250
    recharge_time_s: 350
  }
  weapons { dps_total: 522.7 dps_with_reload: 448.1 alpha_volley: 1320 }
  resources {
    cpu_used: 138 cpu_total: 155
    powergrid_used: 920 powergrid_total: 975
    calibration_used: 50 calibration_total: 400
    drone_bandwidth_used: 20 drone_bandwidth_total: 25
  }
  shield {
    hp: 1371 ehp: 5810
    resistances { em: 0.0 thermal: 0.2 kinetic: 0.4 explosive: 0.5 }
  }
  armor {
    hp: 2016 ehp: 14820
    resistances { em: 0.5 thermal: 0.35 kinetic: 0.35 explosive: 0.1 }
  }
  hull {
    hp: 2250 ehp: 2250
    resistances { em: 0.0 thermal: 0.0 kinetic: 0.0 explosive: 0.0 }
  }
  mobility {
    max_velocity_ms: 1480
    warp_speed_au_s: 4.5
    align_time_s: 5.9
    signature_radius_m: 125
  }
  targeting {
    max_target_range_m: 52500
    scan_resolution_mm: 290
    max_locked_targets: 6
    radar_strength: 0
    ladar_strength: 0
    magnetometric_strength: 15
    gravimetric_strength: 0
  }
  drones {
    max_active_drones: 5
    control_range_m: 60000
    bay_capacity_m3: 100
    bay_used_m3: 60
  }
  cargo {
    mass_kg: 11010000
    capacity_m3: 480
  }
}
```

Serialization is plain protobuf wire format; transport (file, link, API body) is
left to the caller.
