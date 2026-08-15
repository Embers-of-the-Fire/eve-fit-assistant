use std::sync::OnceLock;

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

/// One Rust log record forwarded to the Dart side.
pub struct LogEntry {
    /// Uppercase `log` level name ("ERROR", "WARN", "INFO", "DEBUG", "TRACE").
    pub level: String,
    /// The log target, usually the module path that emitted the record.
    pub target: String,
    /// The formatted log message.
    pub message: String,
}

static LOG_SINK: OnceLock<StreamSink<LogEntry>> = OnceLock::new();

/// Open the persistent Rust→Dart log stream and install the `log` backend that
/// forwards every record to it.
///
/// The sink is stored in a `static` so it is never dropped — dropping the
/// [`StreamSink`] is what signals stream-close — which keeps the stream open
/// for the lifetime of the process. `debug` mirrors the app's debug-log
/// setting so verbose records only cross the sink when it is enabled.
#[frb]
pub fn create_log_stream(sink: StreamSink<LogEntry>, debug: bool) {
    if LOG_SINK.set(sink).is_ok() {
        let _ = log::set_logger(&FRB_LOG_LOGGER);
        log::set_max_level(if debug {
            log::LevelFilter::Debug
        } else {
            log::LevelFilter::Info
        });
    }
}

struct FrbLogLogger;

impl log::Log for FrbLogLogger {
    fn enabled(&self, _metadata: &log::Metadata) -> bool {
        true
    }

    fn log(&self, record: &log::Record) {
        if let Some(sink) = LOG_SINK.get() {
            let _ = sink.add(LogEntry {
                level: record.level().as_str().to_string(),
                target: record.target().to_string(),
                message: record.args().to_string(),
            });
        }
    }

    fn flush(&self) {}
}

static FRB_LOG_LOGGER: FrbLogLogger = FrbLogLogger;
