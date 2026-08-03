use eve_fit_os::{calculate::calculate, protobuf::Database};
use flutter_rust_bridge::frb;

use crate::api::{output::Ship, storage::FitStorage, validation::validate_fit};

/// Resolved file paths for the five `.pb2` data files the fitting engine requires.
///
/// Construct with [`FitEnginePath::from_root`] to derive all paths from a single
/// directory, or with [`FitEnginePath::from_files`] to supply each path
/// individually for per-file configuration.
pub struct FitEnginePath {
    pub types: String,
    pub dogma_attributes: String,
    pub dogma_effects: String,
    pub type_dogma: String,
    pub buff_collections: String,
}

impl FitEnginePath {
    /// Derive all file paths from a root directory.
    ///
    /// Expects `{root}/types.pb2`, `{root}/dogmaAttributes.pb2`,
    /// `{root}/dogmaEffects.pb2`, `{root}/typeDogma.pb2`, and
    /// `{root}/dbuffcollections.pb2`.
    pub fn from_root(root: String) -> Self {
        let r = std::path::Path::new(&root);
        Self {
            types: r
                .join("types")
                .with_extension("pb2")
                .to_string_lossy()
                .into_owned(),
            dogma_attributes: r
                .join("dogmaAttributes")
                .with_extension("pb2")
                .to_string_lossy()
                .into_owned(),
            dogma_effects: r
                .join("dogmaEffects")
                .with_extension("pb2")
                .to_string_lossy()
                .into_owned(),
            type_dogma: r
                .join("typeDogma")
                .with_extension("pb2")
                .to_string_lossy()
                .into_owned(),
            buff_collections: r
                .join("dbuffcollections")
                .with_extension("pb2")
                .to_string_lossy()
                .into_owned(),
        }
    }

    /// Construct with explicit per-file paths.
    pub fn from_files(
        types: String,
        dogma_attributes: String,
        dogma_effects: String,
        type_dogma: String,
        buff_collections: String,
    ) -> Self {
        Self {
            types,
            dogma_attributes,
            dogma_effects,
            type_dogma,
            buff_collections,
        }
    }
}

pub struct FitEngine {
    data: FitEngineData,
}

impl FitEngine {
    #[frb(sync)]
    pub fn new(data: FitEngineData) -> Self {
        Self { data }
    }

    #[frb]
    pub fn emulate(&self, fit: &FitStorage) -> Ship {
        let out = calculate(fit.get_container(), &self.data.database);
        let mut ship = Ship::from_native(out);
        ship.validation_issues = validate_fit(fit, &ship, &self.data.database);
        ship
    }
}

pub struct FitEngineData {
    database: Database,
}

impl FitEngineData {
    /// Initialize the engine database from a [`FitEnginePath`].
    ///
    /// Use [`FitEnginePath::from_files`] for per-file configuration or
    /// [`FitEnginePath::from_root`] when all `.pb2` files live under a single
    /// directory.
    #[frb]
    pub fn init(path: FitEnginePath) -> anyhow::Result<Self> {
        Ok(Self {
            database: Database::init_from_files(
                &path.types,
                &path.dogma_attributes,
                &path.dogma_effects,
                &path.type_dogma,
                &path.buff_collections,
            )?,
        })
    }

    /// Initialize the engine database from in-memory `.pb2` bytes.
    ///
    /// The web counterpart of [`Self::init`]: OPFS blobs have no native file
    /// path, so the Dart side reads the five engine files through the blob
    /// store and passes their bytes directly.
    #[frb]
    pub fn init_bytes(
        types: Vec<u8>,
        dogma_attributes: Vec<u8>,
        dogma_effects: Vec<u8>,
        type_dogma: Vec<u8>,
        buff_collections: Vec<u8>,
    ) -> anyhow::Result<Self> {
        Ok(Self {
            database: Database::init_from_bytes(
                &dogma_attributes,
                &dogma_effects,
                &type_dogma,
                &types,
                &buff_collections,
            )?,
        })
    }
}
