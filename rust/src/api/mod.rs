use data::EveDatabase;

pub mod data;
pub mod error;
pub mod proxy;
pub mod schema;
pub mod simple;

pub(crate) mod validate;

pub struct CalculateOutput {
    pub ship: proxy::ShipProxy,
    pub errors: Vec<error::SlotInfo>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn calculate(db: &EveDatabase, fit: schema::Fit) -> CalculateOutput {
    let err = validate::validate(&fit, &db.inner);
    let ship = data::calculate(db, fit);
    CalculateOutput { ship, errors: err }
}
