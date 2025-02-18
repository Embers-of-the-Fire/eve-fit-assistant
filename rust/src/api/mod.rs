use std::collections::HashMap;

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

#[flutter_rust_bridge::frb(sync)]
pub fn get_type_attr(db: &EveDatabase, type_id: i32) -> HashMap<i32, f64> {
    let info = db
        .inner
        .type_dogma
        .get(&type_id)
        .map(|t| &t.attributes)
        .unwrap_or(&vec![])
        .into_iter()
        .map(|el| (el.attribute_id, el.value))
        .collect();
    info
}
