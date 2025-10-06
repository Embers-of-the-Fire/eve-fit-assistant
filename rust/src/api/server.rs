use eve_fit_os::{calculate::calculate, protobuf::Database};
use flutter_rust_bridge::frb;

use crate::api::{output::Ship, storage::FitStorage};

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
        Ship::from_native(out)
    }
}

pub struct FitEngineData {
    database: Database,
}

impl FitEngineData {
    #[frb]
    pub fn init(static_root_path: &str) -> anyhow::Result<Self> {
        Ok(Self {
            database: Database::init(static_root_path)?,
        })
    }
}
