pub mod agent;
pub mod config;
pub mod error;
pub mod event;
pub mod models;

pub use rig::message::Message;

use std::sync::OnceLock;

use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

pub fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .build()
            .expect("failed to build efa-chat tokio runtime")
    })
}
