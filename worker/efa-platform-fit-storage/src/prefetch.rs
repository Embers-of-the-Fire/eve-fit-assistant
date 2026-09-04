use std::collections::{BTreeSet, HashMap, HashSet};
use std::future::Future;
use std::rc::Rc;

use prost::Message;
use worker::d1::D1Database;

use crate::d1::{self, CatalogEntry};
use crate::error::ApiError;
use crate::proto::{efos, fit as pb, platform_data};
use crate::provider::{
    FitDataProvider, TypeDogmaItem, decode_buff, decode_dogma_attribute, decode_dogma_effect,
    decode_type, decode_type_dogma,
};

/// Warfare-buff attribute IDs consulted by the engine's pass 4, flattened
/// from the engine's own table so the two can never drift.
///
/// Source: `eve_fit_os::calculate::WARFARE_BUFFS`
/// (`packages/eve-fit-os/src/calculate/pass_4.rs`).
pub const WARFARE_BUFF_ATTRIBUTE_IDS: [i32; 8] =
    flatten_buff_pairs(eve_fit_os::calculate::WARFARE_BUFFS);

const fn flatten_buff_pairs(pairs: [(i32, i32); 4]) -> [i32; 8] {
    let mut ids = [0; 8];
    let mut i = 0;
    while i < pairs.len() {
        ids[i * 2] = pairs[i].0;
        ids[i * 2 + 1] = pairs[i].1;
        i += 1;
    }
    ids
}

/// Isolate-cache key: the engine data snapshot selector.
pub type SnapshotKey = (String, String);

/// Isolate-cache entry for a segment catalog, keyed by
/// `(snapshot_id, family code)`.
type CatalogCache = HashMap<(i64, i64), Rc<Vec<CatalogEntry>>>;

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

/// Row families of `efa-snapshot-registry` (spec §7.2). The codes are
/// mirrored in the sync worker and driver
/// (`worker/efa-platform-data-sync/src/session.ts`,
/// `bootstrap/data/d1/sync.py`).
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
    pub fn code(self) -> i64 {
        match self {
            Family::Types => 0,
            Family::TypeDogma => 1,
            Family::DogmaAttributes => 2,
            Family::DogmaEffects => 3,
            Family::Buffs => 4,
            Family::TypeMeta => 5,
        }
    }

    /// Diagnostic name for error messages (the v1 table name).
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
    // Resolved registry ids of complete snapshots; one D1 query per snapshot
    // per isolate instead of one per request.
    static SNAPSHOT_IDS: std::cell::RefCell<HashMap<SnapshotKey, i64>> =
        std::cell::RefCell::new(HashMap::new());
    // Segment catalogs per (snapshot_id, family code), in stream order.
    // Frozen at snapshot completion.
    static CATALOGS: std::cell::RefCell<CatalogCache> =
        std::cell::RefCell::new(HashMap::new());
    // Raw segment bytes by blob id. Segments are content-addressed and
    // shared verbatim across snapshots, so this cache is global, not keyed
    // by snapshot. Sits under the decoded-entry cache: a warm segment cache
    // hit skips the D1 round trip but still decodes the wanted entries.
    static SEGMENTS: std::cell::RefCell<HashMap<i64, Rc<[u8]>>> =
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
        match cache.entry(key) {
            std::collections::hash_map::Entry::Occupied(mut entry) => {
                entry.get_mut().merge(data);
            }
            std::collections::hash_map::Entry::Vacant(entry) => {
                entry.insert(data);
            }
        }
    });
}

/// The cached registry id of a complete snapshot, if resolved before.
pub fn snapshot_id_get(key: &SnapshotKey) -> Option<i64> {
    SNAPSHOT_IDS.with(|ids| ids.borrow().get(key).copied())
}

/// Cache the registry id of a complete snapshot. Snapshot rows are frozen at
/// completion, so the mapping never changes.
pub fn snapshot_id_put(key: SnapshotKey, snapshot_id: i64) {
    SNAPSHOT_IDS.with(|ids| {
        ids.borrow_mut().insert(key, snapshot_id);
    });
}

/// One fetch against a family: `ids == None` means the whole family (buffs).
#[derive(Debug, Clone)]
pub struct FetchRequest {
    pub family: Family,
    pub ids: Option<Vec<i32>>,
}

// ---------------------------------------------------------------------------
// Folded per-family segments (migrations/0003_folded.sql).
//
// Segment format (self-contained, entries sorted by entry id):
//   u32 count
//   count x { i32 entry_id, u32 offset, u32 length }  -- offset from segment
//   payload bytes (concatenated per-entry protobufs)
// ---------------------------------------------------------------------------

const SEGMENT_HEADER_BYTES: usize = 4;
const SEGMENT_INDEX_ENTRY_BYTES: usize = 12;

fn catalog_get(snapshot_id: i64, family_code: i64) -> Option<Rc<Vec<CatalogEntry>>> {
    CATALOGS.with(|catalogs| catalogs.borrow().get(&(snapshot_id, family_code)).cloned())
}

fn catalog_put(snapshot_id: i64, family_code: i64, catalog: Rc<Vec<CatalogEntry>>) {
    CATALOGS.with(|catalogs| {
        catalogs
            .borrow_mut()
            .insert((snapshot_id, family_code), catalog);
    });
}

fn segment_get(blob_id: i64) -> Option<Rc<[u8]>> {
    SEGMENTS.with(|segments| segments.borrow().get(&blob_id).cloned())
}

fn segment_put_all(fetched: Vec<(i64, Vec<u8>)>) {
    SEGMENTS.with(|segments| {
        let mut segments = segments.borrow_mut();
        for (blob_id, content) in fetched {
            segments.insert(blob_id, Rc::from(content.into_boxed_slice()));
        }
    });
}

/// Parse a segment's index: `(entry_id, offset, length)` per entry, sorted
/// by entry id. Bounds-checked; corrupt segments are an internal error,
/// never a panic.
fn segment_index(segment: &[u8]) -> Result<Vec<(i32, u32, u32)>, ApiError> {
    let read_u32 = |at: usize| -> Result<u32, ApiError> {
        segment
            .get(at..at + 4)
            .map(|b| u32::from_le_bytes(b.try_into().expect("slice of 4")))
            .ok_or_else(|| ApiError::internal("corrupt segment: truncated header"))
    };
    let count = read_u32(0)? as usize;
    // Guard the header against unchecked 32-bit arithmetic on wasm32: an
    // overflowing `count * SEGMENT_INDEX_ENTRY_BYTES` would wrap small
    // enough to pass the truncation check, and Vec::with_capacity(count)
    // on an unvalidated count would abort the instance. Only a count
    // whose index provably fits in the segment reaches the allocation.
    count
        .checked_mul(SEGMENT_INDEX_ENTRY_BYTES)
        .and_then(|bytes| bytes.checked_add(SEGMENT_HEADER_BYTES))
        .filter(|&bytes| bytes <= segment.len())
        .ok_or_else(|| ApiError::internal("corrupt segment: truncated index"))?;
    let mut entries = Vec::with_capacity(count);
    for i in 0..count {
        let at = SEGMENT_HEADER_BYTES + i * SEGMENT_INDEX_ENTRY_BYTES;
        let entry_id = read_u32(at)? as i32;
        let offset = read_u32(at + 4)?;
        let length = read_u32(at + 8)?;
        let in_bounds = (offset as usize)
            .checked_add(length as usize)
            .is_some_and(|end| end <= segment.len());
        if !in_bounds {
            return Err(ApiError::internal("corrupt segment: payload out of bounds"));
        }
        entries.push((entry_id, offset, length));
    }
    Ok(entries)
}

/// Slice payloads out of a segment: `wanted == None` extracts every entry
/// (whole-family fetch), otherwise binary-searches the sorted index per id
/// and returns only the ids present.
pub fn segment_extract(
    segment: &[u8],
    wanted: Option<&[i32]>,
) -> Result<Vec<(i32, Vec<u8>)>, ApiError> {
    let index = segment_index(segment)?;
    match wanted {
        None => Ok(index
            .into_iter()
            .map(|(id, offset, length)| {
                (
                    id,
                    segment[offset as usize..(offset + length) as usize].to_vec(),
                )
            })
            .collect()),
        Some(ids) => {
            let mut sorted: Vec<i32> = ids.to_vec();
            sorted.sort_unstable();
            sorted.dedup();
            let mut out = Vec::new();
            for id in sorted {
                if let Ok(i) = index.binary_search_by_key(&id, |entry| entry.0) {
                    let (_, offset, length) = index[i];
                    out.push((
                        id,
                        segment[offset as usize..(offset + length) as usize].to_vec(),
                    ));
                }
            }
            Ok(out)
        }
    }
}

/// Route an entry id to its catalog segment by `[first, last]` range. The
/// catalog is sorted by seq (= ascending id ranges, non-overlapping), so
/// this is one binary search. Ids outside every range route nowhere — the
/// family simply has no such row.
pub fn find_segment(catalog: &[CatalogEntry], id: i32) -> Option<usize> {
    let i = catalog.partition_point(|entry| entry.last_entry_id < id);
    let entry = catalog.get(i)?;
    (entry.first_entry_id <= id).then_some(i)
}

/// Family fetch over folded segments: the catalog is cached per
/// (snapshot, family) and raw segments per blob id — both are frozen at
/// snapshot completion — so warm requests slice payloads straight from the
/// isolate cache.
pub async fn fetch_family(
    db: &D1Database,
    snapshot_id: i64,
    request: FetchRequest,
) -> anyhow::Result<Vec<(i32, Vec<u8>)>> {
    let family_code = request.family.code();
    let catalog = match catalog_get(snapshot_id, family_code) {
        Some(catalog) => catalog,
        None => {
            let catalog = Rc::new(d1::fetch_catalog(db, snapshot_id, family_code).await?);
            catalog_put(snapshot_id, family_code, catalog.clone());
            catalog
        }
    };

    // Route the wanted ids to their segments: blob id -> ids within it
    // (`None` = the whole segment).
    let mut wanted: HashMap<i64, Option<Vec<i32>>> = HashMap::new();
    match &request.ids {
        None => {
            for entry in catalog.iter() {
                wanted.insert(entry.blob_id, None);
            }
        }
        Some(ids) => {
            for id in ids {
                if let Some(i) = find_segment(&catalog, *id) {
                    let blob_id = catalog[i].blob_id;
                    match wanted.entry(blob_id) {
                        std::collections::hash_map::Entry::Vacant(slot) => {
                            slot.insert(Some(vec![*id]));
                        }
                        std::collections::hash_map::Entry::Occupied(mut slot) => {
                            if let Some(ids) = slot.get_mut() {
                                ids.push(*id);
                            }
                        }
                    }
                }
            }
        }
    }

    // Fetch only the segments this isolate has not seen; content addressing
    // makes segments shared across snapshots.
    let missing: Vec<i64> = wanted
        .keys()
        .filter(|blob_id| segment_get(**blob_id).is_none())
        .copied()
        .collect();
    if !missing.is_empty() {
        segment_put_all(d1::fetch_segments(db, &missing).await?);
    }

    let mut out = Vec::new();
    for (blob_id, ids) in wanted {
        let segment = segment_get(blob_id)
            .ok_or_else(|| anyhow::anyhow!("segment {blob_id} missing after fetch"))?;
        out.extend(segment_extract(&segment, ids.as_deref())?);
    }
    Ok(out)
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
    // tolerated (empty names, no icon). Includes the mutated type IDs of
    // dynamic items: the snapshot displays the mutated type while the engine
    // calculates on the base type.
    let mut meta_ids = seeds.clone();
    meta_ids.extend(
        state
            .dynamic_items
            .iter()
            .filter_map(|d| d.type_id.map(|t| t as i32)),
    );
    let wanted = missing(meta_ids.iter(), &cached_keys(&data.type_meta));
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

/// Resolve baked `icon_url`s for the fit's used types, alongside `type_meta`
/// (submit path only). Best-effort: any catalog-chain failure yields an
/// empty map and consumers fall back to their default icon resolution — a
/// storage outage must never fail a fit submit.
pub async fn resolve_icon_urls(
    env: &worker::Env,
    server_id: &str,
    metas: &HashMap<i32, platform_data::PlatformTypeMeta>,
) -> HashMap<i32, String> {
    crate::icons::resolve_icon_urls(env, server_id, metas).await
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::proto::fit::fit_module;

    fn run<F: std::future::Future>(future: F) -> F::Output {
        futures::executor::block_on(future)
    }

    type FetchResult = std::future::Ready<anyhow::Result<Vec<(i32, Vec<u8>)>>>;

    /// Fold rows into segments, mirroring `bootstrap/data/d1/sync.py`'s
    /// `fold_family` (u32 count + (i32 id, u32 off, u32 len) index +
    /// payloads, greedy-packed at entry boundaries). Fixtures use a small
    /// cap so families split into several segments and exercise routing.
    fn fold_rows(
        rows: &[(i32, Vec<u8>)],
        max_bytes: usize,
        next_blob_id: &mut i64,
    ) -> (Vec<CatalogEntry>, HashMap<i64, Vec<u8>>) {
        let mut sorted = rows.to_vec();
        sorted.sort_by_key(|(id, _)| *id);
        let mut catalog = Vec::new();
        let mut blobs = HashMap::new();
        let mut current: Vec<(i32, Vec<u8>)> = Vec::new();
        let mut size = SEGMENT_HEADER_BYTES;
        let mut flush = |current: &mut Vec<(i32, Vec<u8>)>, catalog: &mut Vec<CatalogEntry>| {
            if current.is_empty() {
                return;
            }
            let mut bytes = Vec::with_capacity(
                current.iter().map(|(_, c)| c.len()).sum::<usize>()
                    + SEGMENT_HEADER_BYTES
                    + SEGMENT_INDEX_ENTRY_BYTES * current.len(),
            );
            bytes.extend_from_slice(&(current.len() as u32).to_le_bytes());
            let mut data_offset =
                (SEGMENT_HEADER_BYTES + SEGMENT_INDEX_ENTRY_BYTES * current.len()) as u32;
            let mut payloads = Vec::new();
            for (id, content) in current.iter() {
                bytes.extend_from_slice(&id.to_le_bytes());
                bytes.extend_from_slice(&data_offset.to_le_bytes());
                bytes.extend_from_slice(&(content.len() as u32).to_le_bytes());
                payloads.extend_from_slice(content);
                data_offset += content.len() as u32;
            }
            bytes.extend_from_slice(&payloads);
            *next_blob_id += 1;
            catalog.push(CatalogEntry {
                blob_id: *next_blob_id,
                first_entry_id: current.first().unwrap().0,
                last_entry_id: current.last().unwrap().0,
            });
            blobs.insert(*next_blob_id, bytes);
            current.clear();
        };
        for (id, content) in sorted {
            let entry_size = SEGMENT_INDEX_ENTRY_BYTES + content.len();
            if !current.is_empty() && size + entry_size > max_bytes {
                flush(&mut current, &mut catalog);
                size = SEGMENT_HEADER_BYTES;
            }
            current.push((id, content));
            size += entry_size;
        }
        flush(&mut current, &mut catalog);
        (catalog, blobs)
    }

    /// Segment-backed fixture: rows are folded into segments and served
    /// through the production routing/extraction path.
    struct Fixture {
        catalogs: HashMap<Family, Vec<CatalogEntry>>,
        blobs: HashMap<i64, Vec<u8>>,
        requests: std::cell::RefCell<Vec<FetchRequest>>,
    }

    impl Fixture {
        fn new() -> Fixture {
            Fixture {
                catalogs: HashMap::new(),
                blobs: HashMap::new(),
                requests: std::cell::RefCell::new(Vec::new()),
            }
        }

        fn insert_family(&mut self, family: Family, rows: Vec<(i32, Vec<u8>)>) {
            let mut next_blob_id = self.blobs.keys().copied().max().unwrap_or(0);
            // Small cap: fixture families split into multiple segments.
            let (catalog, blobs) = fold_rows(&rows, 128, &mut next_blob_id);
            self.catalogs.insert(family, catalog);
            self.blobs.extend(blobs);
        }

        fn fetcher(&self) -> impl FnMut(FetchRequest) -> FetchResult + '_ {
            move |req| {
                let catalog = self.catalogs.get(&req.family).cloned().unwrap_or_default();
                let rows = match &req.ids {
                    None => catalog
                        .iter()
                        .flat_map(|entry| {
                            segment_extract(&self.blobs[&entry.blob_id], None)
                                .expect("fixture segments are well-formed")
                        })
                        .collect(),
                    Some(ids) => {
                        let mut by_segment: HashMap<i64, Vec<i32>> = HashMap::new();
                        for id in ids {
                            if let Some(i) = find_segment(&catalog, *id) {
                                by_segment.entry(catalog[i].blob_id).or_default().push(*id);
                            }
                        }
                        by_segment
                            .into_iter()
                            .flat_map(|(blob_id, ids)| {
                                segment_extract(&self.blobs[&blob_id], Some(&ids))
                                    .expect("fixture segments are well-formed")
                            })
                            .collect()
                    }
                };
                self.requests.borrow_mut().push(req);
                std::future::ready(Ok(rows))
            }
        }
    }

    #[test]
    fn segment_extract_whole_and_subset() {
        let rows = vec![
            (-64, b"negative".to_vec()),
            (10, b"ten".to_vec()),
            (11, b"eleven".to_vec()),
        ];
        let mut next_blob_id = 0;
        let (catalog, blobs) = fold_rows(&rows, usize::MAX, &mut next_blob_id);
        assert_eq!(catalog.len(), 1);
        let segment = &blobs[&catalog[0].blob_id];

        let all = segment_extract(segment, None).unwrap();
        assert_eq!(
            all,
            vec![
                (-64, b"negative".to_vec()),
                (10, b"ten".to_vec()),
                (11, b"eleven".to_vec())
            ]
        );

        // Binary search finds present ids and skips missing ones.
        let subset = segment_extract(segment, Some(&[11, 999, -64])).unwrap();
        assert_eq!(
            subset,
            vec![(-64, b"negative".to_vec()), (11, b"eleven".to_vec())]
        );
    }

    #[test]
    fn segment_extract_rejects_corrupt_segments() {
        let rows = vec![(1, b"payload".to_vec())];
        let mut next_blob_id = 0;
        let (catalog, blobs) = fold_rows(&rows, usize::MAX, &mut next_blob_id);
        let segment = &blobs[&catalog[0].blob_id];

        assert!(segment_extract(&segment[..2], None).is_err()); // truncated count
        assert!(segment_extract(&segment[..8], None).is_err()); // truncated index
        let mut corrupted = segment.clone();
        // The first (only) index entry's length field, at 4 + 0*12 + 8.
        corrupted[12..16].copy_from_slice(&u32::MAX.to_le_bytes()); // payload out of bounds
        assert!(segment_extract(&corrupted, None).is_err());

        // A count that would overflow `count * SEGMENT_INDEX_ENTRY_BYTES`
        // on a 32-bit target is rejected before any allocation.
        let mut huge_count = segment.clone();
        huge_count[0..4].copy_from_slice(&u32::MAX.to_le_bytes());
        assert!(segment_extract(&huge_count, None).is_err());

        // offset + length overflowing u32 is rejected, not wrapped.
        let mut wrapped_end = segment.clone();
        wrapped_end[8..12].copy_from_slice(&u32::MAX.to_le_bytes()); // offset
        wrapped_end[12..16].copy_from_slice(&2u32.to_le_bytes()); // length
        assert!(segment_extract(&wrapped_end, None).is_err());
    }

    #[test]
    fn find_segment_routes_by_entry_id_range() {
        let catalog = vec![
            CatalogEntry {
                blob_id: 1,
                first_entry_id: -10,
                last_entry_id: 0,
            },
            CatalogEntry {
                blob_id: 2,
                first_entry_id: 1,
                last_entry_id: 10,
            },
            CatalogEntry {
                blob_id: 3,
                first_entry_id: 20,
                last_entry_id: 30,
            },
        ];
        // Boundaries and interiors route to their segment.
        assert_eq!(find_segment(&catalog, -10), Some(0));
        assert_eq!(find_segment(&catalog, 0), Some(0));
        assert_eq!(find_segment(&catalog, 5), Some(1));
        assert_eq!(find_segment(&catalog, 10), Some(1));
        assert_eq!(find_segment(&catalog, 20), Some(2));
        assert_eq!(find_segment(&catalog, 30), Some(2));
        // Outside every range: nowhere.
        assert_eq!(find_segment(&catalog, -11), None);
        assert_eq!(find_segment(&catalog, 15), None);
        assert_eq!(find_segment(&catalog, 31), None);
        assert_eq!(find_segment(&[], 1), None);
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
                type_id: Some(210),
            }],
            ..Default::default()
        }
    }

    fn full_fixture() -> Fixture {
        let mut fixture = Fixture::new();
        fixture.insert_family(
            Family::Types,
            [100, 200, 201, 300, 400]
                .into_iter()
                .map(|id| (id, ty(1)))
                .collect(),
        );
        // ship: attr 10; module 200: attrs 11, 12 + effect 1000;
        // charge 300: attr 13; dynamic base 201: attr 14; skill 400: attr 15.
        fixture.insert_family(
            Family::TypeDogma,
            vec![
                (100, dogma(&[(10, 1.0)], &[])),
                (200, dogma(&[(11, 1.0), (12, 2.0)], &[1000])),
                (201, dogma(&[(14, 1.0)], &[])),
                (300, dogma(&[(13, 1.0)], &[])),
                (400, dogma(&[(15, 1.0)], &[])),
            ],
        );
        fixture.insert_family(
            Family::DogmaEffects,
            vec![(1000, effect(Some(20), Some(21)))],
        );
        fixture.insert_family(
            Family::DogmaAttributes,
            [10, 11, 12, 13, 14, 15, 20, 21, 30]
                .into_iter()
                .chain(WARFARE_BUFF_ATTRIBUTE_IDS)
                .map(|id| (id, attr()))
                .collect(),
        );
        fixture.insert_family(Family::Buffs, vec![(1, buff(30))]);
        fixture.insert_family(
            Family::TypeMeta,
            [100, 200, 201, 300, 400]
                .into_iter()
                .map(|id| (id, meta("Name")))
                // Mutated type of the dynamic item: metadata only, not an
                // engine type.
                .chain([(210, meta("Mutated"))])
                .collect(),
        );
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
        // Mutated type: metadata prefetched, but not seeded as an engine type.
        assert!(data.type_meta.contains_key(&210));
        assert!(!data.types.contains_key(&210));
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
        let fixture = Fixture::new();
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
