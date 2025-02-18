use super::{proxy, schema};

#[flutter_rust_bridge::frb(unignore, opaque)]
pub struct EveDatabase {
    pub(crate) inner: eve_fit_os::protobuf::Database,
}

impl EveDatabase {
    pub fn init(
        dogma_attr_buffer: &[u8],
        dogma_effect_buffer: &[u8],
        type_dogma_buffer: &[u8],
        types_buffer: &[u8],
    ) -> anyhow::Result<Self> {
        let inner = eve_fit_os::protobuf::Database::init_from_bytes(
            dogma_attr_buffer,
            dogma_effect_buffer,
            type_dogma_buffer,
            types_buffer,
        )?;

        Ok(Self { inner })
    }
}

#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn calculate(db: &EveDatabase, fit: schema::Fit) -> proxy::ShipProxy {
    let container = fit.into_native();
    let out = eve_fit_os::calculate::calculate(&container, &db.inner);
    proxy::ShipProxy::from_native(out)
}
