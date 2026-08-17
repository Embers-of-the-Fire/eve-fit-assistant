use std::collections::{BTreeSet, HashMap, HashSet};
use std::future::Future;

use prost::Message;

use crate::error::ApiError;
use crate::proto::{efos, fit as pb, platform_data};
use crate::provider::{
    FitDataProvider, TypeDogmaItem, decode_buff, decode_dogma_attribute, decode_dogma_effect,
    decode_type, decode_type_dogma,
};

/// Warfare-buff attribute IDs consulted by the engine's pass 4. The literal is
/// file-private in the engine; this copy is version-locked via the path
/// dependency.
///
/// Source: `packages/eve-fit-os/src/calculate/pass_4.rs` (`WARFARE_BUFFS`).
pub const WARFARE_BUFF_ATTRIBUTE_IDS: [i32; 8] = [2468, 2469, 2470, 2471, 2472, 2473, 2536, 2537];

/// Isolate-cache key: the engine data snapshot selector.
pub type SnapshotKey = (String, String);

/// Accumulated decoded engine data for one `(server_id, snapshot_hash)`. The
/// isolate cache is additive: warm requests skip already-seen rows entirely
/// (spec §7.4).
#[derive(Clone, Default)]
pub struct SnapshotData {
    pub types: HashMap<i32, eve_fit_os::fit::Type>,
    pub type_dogma: HashMap<i32, TypeDogmaItem>,
    pub dogma_attributes: HashMap<i32, eve_fit_os::fit::DogmaAttribute>,
    pub dogma_effects: HashMap<i32, eve_fit_os::fit::DogmaEffect>,
    pub buffs: HashMap<i32, eve_fit_os::fit::Buff>,
    pub buffs_loaded: bool,
    pub type_meta: HashMap<i32, platform_data::PlatformTypeMeta>,
    /// Number of degraded buff enum decodes, for logging (never an error).
    pub decode_warnings: u32,
}

impl SnapshotData {
    /// Merge another (newer) accumulation into this one; used when writing
    /// back to the isolate cache so interleaved requests don't lose entries.
    pub fn merge(&mut self, other: SnapshotData) {
        self.types.extend(other.types);
        self.type_dogma.extend(other.type_dogma);
        self.dogma_attributes.extend(other.dogma_attributes);
        self.dogma_effects.extend(other.dogma_effects);
        self.buffs.extend(other.buffs);
        self.buffs_loaded |= other.buffs_loaded;
        self.type_meta.extend(other.type_meta);
        self.decode_warnings += other.decode_warnings;
    }

    pub fn provider(&self) -> FitDataProvider {
        FitDataProvider::from_maps(
            self.types.clone(),
            self.type_dogma.clone(),
            self.dogma_attributes.clone(),
            self.dogma_effects.clone(),
            self.buffs.clone(),
        )
    }
}

/// Row families of `efa-platform-prod` (spec §7.2).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Family {
    Types,
    TypeDogma,
    DogmaAttributes,
    DogmaEffects,
    Buffs,
    TypeMeta,
}

impl Family {
    pub fn table(self) -> &'static str {
        match self {
            Family::Types => "types",
            Family::TypeDogma => "type_dogma",
            Family::DogmaAttributes => "dogma_attributes",
            Family::DogmaEffects => "dogma_effects",
            Family::Buffs => "buffs",
            Family::TypeMeta => "type_meta",
        }
    }
}

// Isolate cache (spec §7.4): accumulated decoded rows keyed by
// `(server_id, snapshot_hash)`. Unbounded by design (R6): current data sizes
// make this a few hundred rows per snapshot; revisit with an LRU if memory
// pressure appears. Only mutated synchronously (never across an `.await`), so
// interleaved requests on the single-threaded isolate cannot conflict.
thread_local! {
    static ISOLATE_CACHE: std::cell::RefCell<HashMap<SnapshotKey, SnapshotData>> =
        std::cell::RefCell::new(HashMap::new());
}

/// Clone out the accumulated data for a snapshot (empty on cold isolates).
pub fn cache_get(key: &SnapshotKey) -> SnapshotData {
    ISOLATE_CACHE.with(|cache| cache.borrow().get(key).cloned().unwrap_or_default())
}

/// Merge a request's freshly fetched rows back into the isolate cache.
pub fn cache_merge(key: SnapshotKey, data: SnapshotData) {
    ISOLATE_CACHE.with(|cache| {
        let mut cache = cache.borrow_mut();
        cache
            .entry(key)
            .and_modify(|existing| existing.merge(data.clone()))
            .or_insert(data);
    });
}

/// One fetch against a family: `ids == None` means the whole family (buffs).
#[derive(Debug, Clone)]
pub struct FetchRequest {
    pub family: Family,
    pub ids: Option<Vec<i32>>,
}

/// The fit's seed type set (spec §7.3, round 0): ship, modules, charges,
/// dynamic base types, drones, fighters, implants, boosters, tactical modes,
/// skills.
pub fn seed_type_ids(state: &pb::FitState) -> BTreeSet<i32> {
    let mut ids = BTreeSet::new();
    ids.insert(state.ship_type_id as i32);

    let dynamic_base: HashMap<i32, i32> = state
        .dynamic_items
        .iter()
        .map(|d| (d.dynamic_id as i32, d.base_type_id as i32))
        .collect();

    for module in &state.modules {
        match &module.item {
            Some(pb::fit_module::Item::TypeId(type_id)) => {
                ids.insert(*type_id as i32);
            }
            Some(pb::fit_module::Item::DynamicId(dynamic_id)) => {
                if let Some(base) = dynamic_base.get(&(*dynamic_id as i32)) {
                    ids.insert(*base);
                }
            }
            None => {}
        }
        if let Some(charge) = module.charge_type_id {
            ids.insert(charge as i32);
        }
    }
    for drone in &state.drones {
        ids.insert(drone.type_id as i32);
    }
    for fighter in &state.fighters {
        ids.insert(fighter.type_id as i32);
    }
    for implant in &state.implants {
        if let Some(type_id) = implant.type_id {
            ids.insert(type_id as i32);
        }
    }
    for booster in &state.boosters {
        ids.insert(booster.type_id as i32);
    }
    for skill in &state.skills {
        ids.insert(skill.type_id as i32);
    }
    for mode in &state.available_tactical_modes {
        ids.insert(mode.type_id as i32);
    }
    if let Some(mode) = state.tactical_mode_type_id {
        ids.insert(mode as i32);
    }
    for base in dynamic_base.values() {
        ids.insert(*base);
    }
    ids
}

fn missing<'a>(ids: impl IntoIterator<Item = &'a i32>, cached: &HashSet<i32>) -> Vec<i32> {
    ids.into_iter()
        .filter(|id| !cached.contains(*id))
        .copied()
        .collect()
}

fn decode_rows<M: Message + Default>(
    family: Family,
    rows: Vec<(i32, Vec<u8>)>,
) -> Result<Vec<(i32, M)>, ApiError> {
    rows.into_iter()
        .map(|(id, bytes)| {
            M::decode(&bytes[..]).map(|m| (id, m)).map_err(|e| {
                ApiError::internal(format!("corrupt {} row {id}: {e}", family.table()))
            })
        })
        .collect()
}

fn cached_keys<T>(map: &HashMap<i32, T>) -> HashSet<i32> {
    map.keys().copied().collect()
}

/// Transitive-closure prefetch (spec §7.3): 3 rounds, ~5–8 queries cold, zero
/// on warm isolate cache hits. Unknown seed types → 422 `unknown_type`.
pub async fn prefetch<F, Fut>(
    data: &mut SnapshotData,
    state: &pb::FitState,
    mut fetch: F,
) -> Result<(), ApiError>
where
    F: FnMut(FetchRequest) -> Fut,
    Fut: Future<Output = anyhow::Result<Vec<(i32, Vec<u8>)>>>,
{
    // Round 0a — the whole buffs family (tiny; collection IDs only known at
    // runtime).
    if !data.buffs_loaded {
        let rows = fetch(FetchRequest {
            family: Family::Buffs,
            ids: None,
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch buffs: {e}")))?;
        for (id, entry) in decode_rows::<efos::buff_collections::Buff>(Family::Buffs, rows)? {
            let (buff, degraded) = decode_buff(&entry);
            if degraded {
                data.decode_warnings += 1;
            }
            data.buffs.insert(id, buff);
        }
        data.buffs_loaded = true;
    }

    // Round 0b — types + type_dogma for the seed set. Missing types → 422.
    let seeds = seed_type_ids(state);

    let wanted = missing(seeds.iter(), &cached_keys(&data.types));
    if !wanted.is_empty() {
        let rows = fetch(FetchRequest {
            family: Family::Types,
            ids: Some(wanted.clone()),
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch types: {e}")))?;
        let mut found = HashSet::new();
        for (id, entry) in decode_rows::<efos::types::Type>(Family::Types, rows)? {
            found.insert(id);
            data.types.insert(id, decode_type(&entry));
        }
        for id in wanted {
            if !found.contains(&id) {
                return Err(ApiError::unknown_type(id));
            }
        }
    }

    let wanted = missing(seeds.iter(), &cached_keys(&data.type_dogma));
    if !wanted.is_empty() {
        let rows = fetch(FetchRequest {
            family: Family::TypeDogma,
            ids: Some(wanted.clone()),
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch type_dogma: {e}")))?;
        let mut found = HashSet::new();
        for (id, entry) in decode_rows::<efos::type_dogma::TypeDogmaEntry>(Family::TypeDogma, rows)?
        {
            found.insert(id);
            data.type_dogma.insert(id, decode_type_dogma(&entry));
        }
        // A type without a type_dogma row behaves as a type with no dogma.
        for id in wanted {
            if !found.contains(&id) {
                data.type_dogma.insert(id, TypeDogmaItem::default());
            }
        }
    }

    // Round 1 — effects referenced by the seed types' type_dogma entries.
    let effect_ids: BTreeSet<i32> = seeds
        .iter()
        .filter_map(|id| data.type_dogma.get(id))
        .flat_map(|item| item.effects.iter().map(|e| e.effect_id))
        .collect();
    let wanted = missing(effect_ids.iter(), &cached_keys(&data.dogma_effects));
    if !wanted.is_empty() {
        let rows = fetch(FetchRequest {
            family: Family::DogmaEffects,
            ids: Some(wanted),
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch dogma_effects: {e}")))?;
        for (id, entry) in
            decode_rows::<efos::dogma_effects::DogmaEffect>(Family::DogmaEffects, rows)?
        {
            data.dogma_effects.insert(id, decode_dogma_effect(&entry));
        }
    }

    // Round 2 — attributes: union of the seed types' attributes, the fetched
    // effects' modifier attribute IDs, the WARFARE_BUFFS literal, and every
    // attribute referenced by buff modifiers.
    let mut attribute_ids: BTreeSet<i32> = WARFARE_BUFF_ATTRIBUTE_IDS.into_iter().collect();
    attribute_ids.extend(
        seeds
            .iter()
            .filter_map(|id| data.type_dogma.get(id))
            .flat_map(|item| item.attributes.iter().map(|a| a.attribute_id)),
    );
    for effect_id in &effect_ids {
        if let Some(effect) = data.dogma_effects.get(effect_id) {
            for modifier in &effect.modifier_info {
                if let Some(id) = modifier.modified_attribute_id {
                    attribute_ids.insert(id);
                }
                if let Some(id) = modifier.modifying_attribute_id {
                    attribute_ids.insert(id);
                }
            }
        }
    }
    for buff in data.buffs.values() {
        attribute_ids.extend(buff.item_modifiers.iter().map(|m| m.dogma_attribute_id));
        attribute_ids.extend(buff.location_modifiers.iter().map(|m| m.dogma_attribute_id));
        attribute_ids.extend(
            buff.location_group_modifiers
                .iter()
                .map(|m| m.dogma_attribute_id),
        );
        attribute_ids.extend(
            buff.location_required_skill_modifiers
                .iter()
                .map(|m| m.dogma_attribute_id),
        );
    }
    let wanted = missing(attribute_ids.iter(), &cached_keys(&data.dogma_attributes));
    if !wanted.is_empty() {
        let rows = fetch(FetchRequest {
            family: Family::DogmaAttributes,
            ids: Some(wanted),
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch dogma_attributes: {e}")))?;
        for (id, entry) in
            decode_rows::<efos::dogma_attributes::DogmaAttribute>(Family::DogmaAttributes, rows)?
        {
            data.dogma_attributes
                .insert(id, decode_dogma_attribute(&entry));
        }
    }

    // Type metadata for name/icon resolution (spec §11); missing rows are
    // tolerated (empty names, no icon).
    let wanted = missing(seeds.iter(), &cached_keys(&data.type_meta));
    if !wanted.is_empty() {
        let rows = fetch(FetchRequest {
            family: Family::TypeMeta,
            ids: Some(wanted),
        })
        .await
        .map_err(|e| ApiError::internal(format!("failed to fetch type_meta: {e}")))?;
        for (id, entry) in decode_rows::<platform_data::PlatformTypeMeta>(Family::TypeMeta, rows)? {
            data.type_meta.insert(id, entry);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::fit::fit_module;

    fn run<F: std::future::Future>(future: F) -> F::Output {
        futures::executor::block_on(future)
    }

    type FetchResult = std::future::Ready<anyhow::Result<Vec<(i32, Vec<u8>)>>>;

    struct Fixture {
        rows: HashMap<Family, HashMap<i32, Vec<u8>>>,
        requests: std::cell::RefCell<Vec<FetchRequest>>,
    }

    impl Fixture {
        fn fetcher(&self) -> impl FnMut(FetchRequest) -> FetchResult + '_ {
            move |req| {
                let rows = match &req.ids {
                    None => self
                        .rows
                        .get(&req.family)
                        .map(|m| m.iter().map(|(id, b)| (*id, b.clone())).collect::<Vec<_>>())
                        .unwrap_or_default(),
                    Some(ids) => ids
                        .iter()
                        .filter_map(|id| {
                            self.rows
                                .get(&req.family)
                                .and_then(|m| m.get(id))
                                .map(|b| (*id, b.clone()))
                        })
                        .collect(),
                };
                self.requests.borrow_mut().push(req);
                std::future::ready(Ok(rows))
            }
        }
    }

    fn ty(group_id: i32) -> Vec<u8> {
        efos::types::Type {
            group_id,
            category_id: 6,
            capacity: None,
            mass: None,
            radius: None,
            volume: None,
        }
        .encode_to_vec()
    }

    fn dogma(attrs: &[(i32, f64)], effects: &[i32]) -> Vec<u8> {
        efos::type_dogma::TypeDogmaEntry {
            dogma_attributes: attrs
                .iter()
                .map(
                    |&(attribute_id, value)| efos::type_dogma::type_dogma_entry::DogmaAttributes {
                        attribute_id,
                        value,
                    },
                )
                .collect(),
            dogma_effects: effects
                .iter()
                .map(
                    |&effect_id| efos::type_dogma::type_dogma_entry::DogmaEffects {
                        effect_id,
                        is_default: false,
                    },
                )
                .collect(),
        }
        .encode_to_vec()
    }

    fn effect(modified: Option<i32>, modifying: Option<i32>) -> Vec<u8> {
        efos::dogma_effects::DogmaEffect {
            effect_category: 0,
            modifier_info: vec![efos::dogma_effects::dogma_effect::ModifierInfo {
                domain: 0,
                func: 0,
                modified_attribute_id: modified,
                modifying_attribute_id: modifying,
                operation: None,
                group_id: None,
                skill_type_id: None,
            }],
            name: "test".to_string(),
        }
        .encode_to_vec()
    }

    fn attr() -> Vec<u8> {
        efos::dogma_attributes::DogmaAttribute {
            published: true,
            default_value: 0.0,
            high_is_good: true,
            stackable: true,
            name: "test".to_string(),
        }
        .encode_to_vec()
    }

    fn buff(attr_id: i32) -> Vec<u8> {
        efos::buff_collections::Buff {
            aggregate_mode: 0,
            buff_id: 1,
            item_modifiers: vec![efos::buff_collections::buff::ItemModifier {
                dogma_attribute_id: attr_id,
            }],
            location_group_modifiers: vec![],
            location_modifiers: vec![],
            location_required_skill_modifiers: vec![],
            operation_name: 7,
            show_output_value_in_ui: 0,
        }
        .encode_to_vec()
    }

    fn meta(name: &str) -> Vec<u8> {
        platform_data::PlatformTypeMeta {
            type_id: 0,
            name: [("en".to_string(), name.to_string())].into_iter().collect(),
            icon_id: Some(1),
            graphic_id: None,
        }
        .encode_to_vec()
    }

    fn simple_state() -> pb::FitState {
        pb::FitState {
            ship_type_id: 100,
            modules: vec![
                pb::FitModule {
                    item: Some(fit_module::Item::TypeId(200)),
                    slot_type: pb::SlotType::High as i32,
                    index: 0,
                    state: pb::slots::SlotState::Active as i32,
                    charge_type_id: Some(300),
                    subsystem_type: None,
                },
                pb::FitModule {
                    item: Some(fit_module::Item::DynamicId(1)),
                    slot_type: pb::SlotType::Low as i32,
                    index: 0,
                    state: pb::slots::SlotState::Online as i32,
                    charge_type_id: None,
                    subsystem_type: None,
                },
            ],
            skills: vec![pb::FitSkill {
                type_id: 400,
                level: 5,
            }],
            dynamic_items: vec![pb::FitDynamicItem {
                dynamic_id: 1,
                base_type_id: 201,
                attributes: vec![],
            }],
            ..Default::default()
        }
    }

    fn full_fixture() -> Fixture {
        let mut fixture = Fixture {
            rows: HashMap::new(),
            requests: std::cell::RefCell::new(Vec::new()),
        };
        for id in [100, 200, 201, 300, 400] {
            fixture
                .rows
                .entry(Family::Types)
                .or_default()
                .insert(id, ty(1));
        }
        // ship: attr 10; module 200: attrs 11, 12 + effect 1000;
        // charge 300: attr 13; dynamic base 201: attr 14; skill 400: attr 15.
        let dogmas = [
            (100, dogma(&[(10, 1.0)], &[])),
            (200, dogma(&[(11, 1.0), (12, 2.0)], &[1000])),
            (201, dogma(&[(14, 1.0)], &[])),
            (300, dogma(&[(13, 1.0)], &[])),
            (400, dogma(&[(15, 1.0)], &[])),
        ];
        for (id, row) in dogmas {
            fixture
                .rows
                .entry(Family::TypeDogma)
                .or_default()
                .insert(id, row);
        }
        fixture
            .rows
            .entry(Family::DogmaEffects)
            .or_default()
            .insert(1000, effect(Some(20), Some(21)));
        for id in [10, 11, 12, 13, 14, 15, 20, 21] {
            fixture
                .rows
                .entry(Family::DogmaAttributes)
                .or_default()
                .insert(id, attr());
        }
        for id in WARFARE_BUFF_ATTRIBUTE_IDS {
            fixture
                .rows
                .entry(Family::DogmaAttributes)
                .or_default()
                .insert(id, attr());
        }
        fixture
            .rows
            .entry(Family::Buffs)
            .or_default()
            .insert(1, buff(30));
        fixture
            .rows
            .entry(Family::DogmaAttributes)
            .or_default()
            .insert(30, attr());
        for id in [100, 200, 201, 300, 400] {
            fixture
                .rows
                .entry(Family::TypeMeta)
                .or_default()
                .insert(id, meta("Name"));
        }
        fixture
    }

    #[test]
    fn prefetch_loads_full_closure() {
        let fixture = full_fixture();
        let mut data = SnapshotData::default();
        run(prefetch(&mut data, &simple_state(), fixture.fetcher())).unwrap();

        for id in [100, 200, 201, 300, 400] {
            assert!(data.types.contains_key(&id), "type {id}");
            assert!(data.type_dogma.contains_key(&id), "type_dogma {id}");
            assert!(data.type_meta.contains_key(&id), "type_meta {id}");
        }
        assert!(data.dogma_effects.contains_key(&1000));
        for id in [10, 11, 12, 13, 14, 15, 20, 21, 30] {
            assert!(data.dogma_attributes.contains_key(&id), "attribute {id}");
        }
        for id in WARFARE_BUFF_ATTRIBUTE_IDS {
            assert!(data.dogma_attributes.contains_key(&id), "warfare {id}");
        }
        assert_eq!(data.buffs.len(), 1);
        assert!(data.buffs_loaded);
    }

    #[test]
    fn prefetch_unknown_seed_type_is_422() {
        let fixture = Fixture {
            rows: HashMap::new(),
            requests: std::cell::RefCell::new(Vec::new()),
        };
        let mut data = SnapshotData::default();
        let err = run(prefetch(&mut data, &simple_state(), fixture.fetcher())).unwrap_err();
        assert_eq!(err.status, 422);
        assert_eq!(err.code, "unknown_type");
    }

    #[test]
    fn warm_cache_skips_fetches() {
        let fixture = full_fixture();
        let mut data = SnapshotData::default();
        run(prefetch(&mut data, &simple_state(), fixture.fetcher())).unwrap();
        let count = fixture.requests.borrow().len();
        run(prefetch(&mut data, &simple_state(), fixture.fetcher())).unwrap();
        assert_eq!(fixture.requests.borrow().len(), count);
    }

    #[test]
    fn seed_set_covers_all_fit_references() {
        let state = pb::FitState {
            tactical_mode_type_id: Some(500),
            available_tactical_modes: vec![pb::FitTacticalModeRef {
                type_id: 500,
                variant: pb::tactical_mode::TacticalModeVariant::Defense as i32,
            }],
            drones: vec![pb::FitDrone {
                type_id: 600,
                state: pb::slots::SlotState::Active as i32,
                quantity: 1,
            }],
            fighters: vec![pb::FitFighter {
                type_id: 700,
                quantity: 1,
                max_squadron_size: 1,
                group: pb::snapshot_fighter::SquadronGroup::Light as i32,
                abilities: vec![],
            }],
            implants: vec![pb::FitImplant {
                slot_index: 1,
                type_id: Some(800),
                state: pb::slots::SlotState::Active as i32,
            }],
            boosters: vec![pb::FitBooster {
                slot_index: 1,
                type_id: 900,
                state: pb::slots::SlotState::Active as i32,
            }],
            ..simple_state()
        };
        let ids = seed_type_ids(&state);
        for id in [100, 200, 201, 300, 400, 500, 600, 700, 800, 900] {
            assert!(ids.contains(&id), "seed {id}");
        }
    }
}
