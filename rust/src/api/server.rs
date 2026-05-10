use eve_fit_os::{calculate::calculate, protobuf::Database};
use flutter_rust_bridge::frb;

use crate::api::{output::Ship, storage::FitStorage, validation::validate_fit};

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
    #[frb]
    pub fn init(static_root_path: &str) -> anyhow::Result<Self> {
        Ok(Self {
            database: Database::init(static_root_path)?,
        })
    }
}
