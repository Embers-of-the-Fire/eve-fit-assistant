//! Non-agent glue that bridges the crate to the host runtime: the shared
//! tokio runtime the agent's async work runs on, and the plumbing that
//! forwards Rust `log` records to the host (e.g. Dart).

pub mod runtime;
