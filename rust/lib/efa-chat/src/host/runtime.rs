use std::sync::OnceLock;

use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// The shared multi-thread tokio runtime that all efa-chat async work runs
/// on. Keeps rig/reqwest off FRB's executor so heavy engine work and streams
/// never block the Dart isolate's event loop.
pub fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .worker_threads(2)
            .build()
            .expect("failed to build efa-chat tokio runtime")
    })
}
