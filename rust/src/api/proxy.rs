use std::collections::HashMap;

use eve_fit_os::calculate;

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone)]
pub struct ShipProxy {
    pub hull: ItemProxy,
    pub modules: ModulesProxy,
    pub implants: Vec<ItemProxy>,
    pub character: ItemProxy,
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
}

impl ModulesProxy {
    // #[flutter_rust_bridge::frb(ignore)]
    pub(crate) fn from_native(native: Vec<calculate::item::Item>) -> Self {
        use calculate::item::SlotType::*;

        let mut out = Self::default();

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
                _ => {}
            }
        }

        out
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
