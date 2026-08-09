use std::sync::OnceLock;

use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

/// The shared tokio runtime that all efa-chat async work runs on. Keeps
/// rig/reqwest off FRB's executor so heavy engine work and streams never
/// block the Dart isolate's event loop. Multi-threaded on native targets;
/// wasm32 has no threads, so it falls back to a current-thread runtime
/// (I/O and time drivers are unavailable there, so `enable_all` is skipped).
pub fn runtime() -> &'static Runtime {
    RUNTIME.get_or_init(build_runtime)
}

#[cfg(not(target_arch = "wasm32"))]
fn build_runtime() -> Runtime {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .worker_threads(2)
        .build()
        .expect("failed to build efa-chat tokio runtime")
}

#[cfg(target_arch = "wasm32")]
fn build_runtime() -> Runtime {
    tokio::runtime::Builder::new_current_thread()
        .build()
        .expect("failed to build efa-chat tokio runtime")
}
