use std::cell::Cell;
use std::collections::HashMap;

use eve_fit_os::fit as ef;
use eve_fit_os::provider::InfoProvider;

use crate::proto::efos;

/// The engine's own `TypeDogmaItem` lives behind its `protobuf` feature; the
/// worker defines its own (spec §7.1).
#[derive(Debug, Clone, Default)]
pub struct TypeDogmaItem {
    pub attributes: Vec<ef::TypeDogmaAttribute>,
    pub effects: Vec<ef::TypeDogmaEffect>,
}

pub fn decode_type(entry: &efos::types::Type) -> ef::Type {
    ef::Type {
        group_id: entry.group_id,
        category_id: entry.category_id,
        capacity: entry.capacity,
        mass: entry.mass,
        radius: entry.radius,
        volume: entry.volume,
    }
}

pub fn decode_type_dogma(entry: &efos::type_dogma::TypeDogmaEntry) -> TypeDogmaItem {
    TypeDogmaItem {
        attributes: entry
            .dogma_attributes
            .iter()
            .map(|a| ef::TypeDogmaAttribute {
                attribute_id: a.attribute_id,
                value: a.value,
            })
            .collect(),
        effects: entry
            .dogma_effects
            .iter()
            .map(|e| ef::TypeDogmaEffect {
                effect_id: e.effect_id,
                is_default: e.is_default,
            })
            .collect(),
    }
}

pub fn decode_dogma_attribute(
    entry: &efos::dogma_attributes::DogmaAttribute,
) -> ef::DogmaAttribute {
    ef::DogmaAttribute {
        default_value: entry.default_value,
        high_is_good: entry.high_is_good,
        stackable: entry.stackable,
    }
}

pub fn decode_dogma_effect(entry: &efos::dogma_effects::DogmaEffect) -> ef::DogmaEffect {
    ef::DogmaEffect {
        effect_category: entry.effect_category,
        modifier_info: entry
            .modifier_info
            .iter()
            .map(|m| ef::DogmaEffectModifierInfo {
                domain: ef::DogmaEffectModifierInfoDomain::from(m.domain),
                func: ef::DogmaEffectModifierInfoFunc::from(m.func),
                modified_attribute_id: m.modified_attribute_id,
                modifying_attribute_id: m.modifying_attribute_id,
                operation: m.operation,
                group_id: m.group_id,
                skill_type_id: m.skill_type_id,
            })
            .collect(),
    }
}

/// Mirrors `Database::init_from_protobuf`, but never panics: unknown buff
/// aggregate-mode/operation ints degrade to a default (the bool return flags
/// the degradation for logging) — a wasm trap is uncatchable (spec §14).
pub fn decode_buff(entry: &efos::buff_collections::Buff) -> (ef::Buff, bool) {
    let mut degraded = false;
    let aggregate_mode = match entry.aggregate_mode {
        0 => ef::BuffAggregateMode::Maximum,
        1 => ef::BuffAggregateMode::Minimum,
        _ => {
            degraded = true;
            ef::BuffAggregateMode::Maximum
        }
    };
    let operation = match entry.operation_name {
        0 => ef::BuffOperation::PreAssign,
        1 => ef::BuffOperation::PreMul,
        2 => ef::BuffOperation::PreDiv,
        3 => ef::BuffOperation::ModAdd,
        4 => ef::BuffOperation::ModSub,
        5 => ef::BuffOperation::PostMul,
        6 => ef::BuffOperation::PostDiv,
        7 => ef::BuffOperation::PostPercent,
        8 => ef::BuffOperation::PostAssign,
        _ => {
            degraded = true;
            ef::BuffOperation::PostAssign
        }
    };
    let buff = ef::Buff {
        aggregate_mode,
        item_modifiers: entry
            .item_modifiers
            .iter()
            .map(|m| ef::BuffItemModifier {
                dogma_attribute_id: m.dogma_attribute_id,
            })
            .collect(),
        location_modifiers: entry
            .location_modifiers
            .iter()
            .map(|m| ef::BuffItemModifier {
                dogma_attribute_id: m.dogma_attribute_id,
            })
            .collect(),
        location_group_modifiers: entry
            .location_group_modifiers
            .iter()
            .map(|m| ef::BuffGroupModifier {
                dogma_attribute_id: m.dogma_attribute_id,
                group_id: m.group_id,
            })
            .collect(),
        location_required_skill_modifiers: entry
            .location_required_skill_modifiers
            .iter()
            .map(|m| ef::BuffSkillModifier {
                dogma_attribute_id: m.dogma_attribute_id,
                skill_id: m.skill_id,
            })
            .collect(),
        operation,
    };
    (buff, degraded)
}

/// Custom `InfoProvider` over hand-built maps of core engine types (spec
/// §7.1). Getter misses return references to cached zero-value placeholders
/// instead of panicking (the trait returns `&T`; a wasm trap is uncatchable)
/// and are counted in `miss_count` — a nonzero count indicates a closure bug
/// (§7.3), not a client error.
pub struct FitDataProvider {
    pub types: HashMap<i32, ef::Type>,
    pub type_dogma: HashMap<i32, TypeDogmaItem>,
    pub dogma_attributes: HashMap<i32, ef::DogmaAttribute>,
    pub dogma_effects: HashMap<i32, ef::DogmaEffect>,
    pub buffs: HashMap<i32, ef::Buff>,

    miss_count: Cell<u32>,
    placeholder_type: ef::Type,
    placeholder_attribute: ef::DogmaAttribute,
    placeholder_effect: ef::DogmaEffect,
    placeholder_buff: ef::Buff,
}

impl Default for FitDataProvider {
    fn default() -> Self {
        Self {
            types: HashMap::new(),
            type_dogma: HashMap::new(),
            dogma_attributes: HashMap::new(),
            dogma_effects: HashMap::new(),
            buffs: HashMap::new(),
            miss_count: Cell::new(0),
            placeholder_type: ef::Type {
                group_id: 0,
                category_id: 0,
                capacity: None,
                mass: None,
                radius: None,
                volume: None,
            },
            placeholder_attribute: ef::DogmaAttribute {
                default_value: 0.0,
                high_is_good: false,
                stackable: false,
            },
            placeholder_effect: ef::DogmaEffect {
                effect_category: 0,
                modifier_info: Vec::new(),
            },
            placeholder_buff: ef::Buff {
                aggregate_mode: ef::BuffAggregateMode::Maximum,
                item_modifiers: Vec::new(),
                location_modifiers: Vec::new(),
                location_group_modifiers: Vec::new(),
                location_required_skill_modifiers: Vec::new(),
                operation: ef::BuffOperation::PostAssign,
            },
        }
    }
}

impl FitDataProvider {
    pub fn from_maps(
        types: HashMap<i32, ef::Type>,
        type_dogma: HashMap<i32, TypeDogmaItem>,
        dogma_attributes: HashMap<i32, ef::DogmaAttribute>,
        dogma_effects: HashMap<i32, ef::DogmaEffect>,
        buffs: HashMap<i32, ef::Buff>,
    ) -> Self {
        Self {
            types,
            type_dogma,
            dogma_attributes,
            dogma_effects,
            buffs,
            ..Self::default()
        }
    }

    pub fn miss_count(&self) -> u32 {
        self.miss_count.get()
    }
}

impl InfoProvider for FitDataProvider {
    fn get_dogma_attributes(&self, type_id: i32) -> Vec<ef::TypeDogmaAttribute> {
        match self.type_dogma.get(&type_id) {
            Some(item) => item.attributes.clone(),
            None => {
                self.miss_count.set(self.miss_count.get() + 1);
                Vec::new()
            }
        }
    }

    fn get_dogma_attribute(&self, attribute_id: i32) -> &ef::DogmaAttribute {
        self.dogma_attributes.get(&attribute_id).unwrap_or_else(|| {
            self.miss_count.set(self.miss_count.get() + 1);
            &self.placeholder_attribute
        })
    }

    fn get_dogma_effects(&self, type_id: i32) -> Vec<ef::TypeDogmaEffect> {
        match self.type_dogma.get(&type_id) {
            Some(item) => item.effects.clone(),
            None => {
                self.miss_count.set(self.miss_count.get() + 1);
                Vec::new()
            }
        }
    }

    fn get_dogma_effect(&self, effect_id: i32) -> &ef::DogmaEffect {
        self.dogma_effects.get(&effect_id).unwrap_or_else(|| {
            self.miss_count.set(self.miss_count.get() + 1);
            &self.placeholder_effect
        })
    }

    fn get_buff(&self, buff_id: i32) -> &ef::Buff {
        self.buffs.get(&buff_id).unwrap_or_else(|| {
            self.miss_count.set(self.miss_count.get() + 1);
            &self.placeholder_buff
        })
    }

    fn get_type(&self, type_id: i32) -> &ef::Type {
        self.types.get(&type_id).unwrap_or_else(|| {
            self.miss_count.set(self.miss_count.get() + 1);
            &self.placeholder_type
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn singleton_misses_return_placeholders_and_count() {
        let provider = FitDataProvider::default();
        assert_eq!(provider.get_type(1).group_id, 0);
        assert_eq!(provider.get_dogma_attribute(2).default_value, 0.0);
        assert_eq!(provider.get_dogma_effect(3).modifier_info.len(), 0);
        assert_eq!(provider.get_buff(4).item_modifiers.len(), 0);
        assert!(provider.get_dogma_attributes(5).is_empty());
        assert!(provider.get_dogma_effects(6).is_empty());
        assert_eq!(provider.miss_count(), 6);
    }

    #[test]
    fn buff_decode_degrades_unknown_enums() {
        let entry = efos::buff_collections::Buff {
            aggregate_mode: 99,
            buff_id: 1,
            item_modifiers: vec![],
            location_group_modifiers: vec![],
            location_modifiers: vec![],
            location_required_skill_modifiers: vec![],
            operation_name: 42,
            show_output_value_in_ui: 0,
        };
        let (buff, degraded) = decode_buff(&entry);
        assert!(degraded);
        assert_eq!(buff.aggregate_mode, ef::BuffAggregateMode::Maximum);
        assert_eq!(buff.operation, ef::BuffOperation::PostAssign);

        let (buff, degraded) = decode_buff(&efos::buff_collections::Buff {
            aggregate_mode: 1,
            operation_name: 7,
            ..entry
        });
        assert!(!degraded);
        assert_eq!(buff.aggregate_mode, ef::BuffAggregateMode::Minimum);
        assert_eq!(buff.operation, ef::BuffOperation::PostPercent);
    }
}
