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
    let mut err = vec![];
    validate::pre_validate(&fit, &db.inner, &mut err);
    let ship = data::calculate(db, fit);
    validate::post_validate(&ship, &db.inner, &mut err);
    CalculateOutput { ship, errors: err }
}
