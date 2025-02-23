use std::collections::HashMap;

use eve_fit_os::calculate;

use super::schema::DamageProfile;

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct ShipProxy {
    pub hull: ItemProxy,
    pub modules: ModulesProxy,
    pub implants: Vec<ItemProxy>,
    pub character: ItemProxy,
    pub damage_profile: DamageProfile,
}

impl ShipProxy {
    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(native: calculate::Ship) -> Self {
        ShipProxy {
            hull: ItemProxy::from_native(native.hull),
            modules: ModulesProxy::from_native(native.modules),
            implants: native
                .implants
                .into_iter()
                .map(ItemProxy::from_native)
                .collect(),
            character: ItemProxy::from_native(native.character),
            damage_profile: DamageProfile {
                em: native.damage_profile.em,
                explosive: native.damage_profile.explosive,
                kinetic: native.damage_profile.kinetic,
                thermal: native.damage_profile.thermal,
            },
        }
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, Default)]
pub struct ModulesProxy {
    pub high: Vec<ItemProxy>,
    pub medium: Vec<ItemProxy>,
    pub low: Vec<ItemProxy>,
    pub rig: Vec<ItemProxy>,
    pub subsystem: Vec<ItemProxy>,
    pub tactical_mode: Option<ItemProxy>,
    pub drones: Vec<DroneProxy>,
    pub fighters: Vec<FighterProxy>,
}

impl ModulesProxy {
    // #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(native: Vec<calculate::item::Item>) -> Self {
        use calculate::item::SlotType::*;

        let mut out = Self::default();

        let mut drones = vec![];
        let mut fighters = vec![];

        for item in native {
            match item.slot.slot_type {
                High => out.high.push(ItemProxy::from_native(item)),
                Medium => out.medium.push(ItemProxy::from_native(item)),
                Low => out.low.push(ItemProxy::from_native(item)),
                Rig => out.rig.push(ItemProxy::from_native(item)),
                SubSystem => out.subsystem.push(ItemProxy::from_native(item)),
                TacticalMode => {
                    out.tactical_mode.replace(ItemProxy::from_native(item));
                }
                DroneBay { .. } => {
                    drones.push(item);
                }
                Fighter { .. } => {
                    fighters.push(item);
                }
                _ => {}
            }
        }

        out.drones = DroneProxy::from_native_grouped(drones);
        out.fighters = FighterProxy::from_native_grouped(fighters);

        out
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct DroneProxy {
    pub group_index: u8,
    pub drones: Vec<ItemProxy>,
}

impl DroneProxy {
    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(group: u8, native: Vec<calculate::item::Item>) -> Self {
        DroneProxy {
            group_index: group,
            drones: native.into_iter().map(ItemProxy::from_native).collect(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native_grouped(native: Vec<calculate::item::Item>) -> Vec<Self> {
        use std::collections::BTreeMap;

        let mut map = BTreeMap::new();
        for drone in native {
            map.entry(match drone.slot.slot_type {
                calculate::item::SlotType::DroneBay { group_id } => group_id,
                _ => 0,
            })
            .or_insert_with(Vec::new)
            .push(drone);
        }

        map.into_iter()
            .map(|(group, drones)| Self::from_native(group, drones))
            .collect()
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct FighterProxy {
    pub group_index: u8,
    pub fighters: Vec<ItemProxy>,
}

impl FighterProxy {
    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(group: u8, native: Vec<calculate::item::Item>) -> Self {
        FighterProxy {
            group_index: group,
            fighters: native.into_iter().map(ItemProxy::from_native).collect(),
        }
    }

    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native_grouped(native: Vec<calculate::item::Item>) -> Vec<Self> {
        use std::collections::BTreeMap;

        let mut map = BTreeMap::new();
        for fighter in native {
            map.entry(match fighter.slot.slot_type {
                calculate::item::SlotType::Fighter { group_id, .. } => group_id,
                _ => 0,
            })
            .or_insert_with(Vec::new)
            .push(fighter);
        }

        map.into_iter()
            .map(|(group, drones)| Self::from_native(group, drones))
            .collect()
    }
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct ItemProxy {
    pub index: Option<i32>,
    pub item_id: i32,
    pub charge: Option<Box<ItemProxy>>,
    pub attributes: HashMap<i32, f64>,
}

impl ItemProxy {
    #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(native: calculate::item::Item) -> Self {
        ItemProxy {
            index: native.slot.index,
            item_id: native.type_id,
            charge: native.charge.map(|t| Box::new(Self::from_native(*t))),
            attributes: native
                .attributes
                .into_iter()
                .map(|(key, value)| (key, value.value.unwrap_or(value.base_value)))
                .collect(),
        }
    }
}
