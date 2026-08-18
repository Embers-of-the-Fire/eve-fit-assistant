use serde_json::{Value, json};

/// API error rendered as `{ "error": code, "message": msg }` (+ `"issues"`
/// for `validation_failed`), per the spec §6 table.
#[derive(Debug)]
pub struct ApiError {
    pub status: u16,
    pub code: &'static str,
    pub message: String,
    pub issues: Option<Value>,
}

impl ApiError {
    pub fn new(status: u16, code: &'static str, message: impl Into<String>) -> Self {
        Self {
            status,
            code,
            message: message.into(),
            issues: None,
        }
    }

    pub fn bad_request(message: impl Into<String>) -> Self {
        Self::new(400, "bad_request", message)
    }

    pub fn unauthorized() -> Self {
        Self::new(401, "unauthorized", "missing or invalid bearer token")
    }

    pub fn not_found(message: impl Into<String>) -> Self {
        Self::new(404, "not_found", message)
    }

    pub fn snapshot_incomplete(server_id: &str, snapshot_hash: &str) -> Self {
        Self::new(
            409,
            "snapshot_incomplete",
            format!("snapshot not registered: {server_id}/{snapshot_hash}"),
        )
    }

    pub fn unknown_type(type_id: i32) -> Self {
        Self::new(422, "unknown_type", format!("unknown type id: {type_id}"))
    }

    pub fn validation_failed(issues: Value) -> Self {
        Self {
            status: 422,
            code: "validation_failed",
            message: "fit failed engine validation".to_string(),
            issues: Some(issues),
        }
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self::new(500, "internal", message)
    }

    pub fn body(&self) -> Value {
        // 5xx messages carry internal detail (D1 errors, secret state); only log
        // them server-side and return a fixed string to clients.
        let message: &str = if self.status >= 500 {
            "internal server error"
        } else {
            &self.message
        };
        let mut body = json!({
            "error": self.code,
            "message": message,
        });
        if let Some(issues) = &self.issues {
            body["issues"] = issues.clone();
        }
        body
    }
}

impl From<prost::DecodeError> for ApiError {
    fn from(err: prost::DecodeError) -> Self {
        Self::bad_request(format!("malformed protobuf: {err}"))
    }
}

impl std::fmt::Display for ApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for ApiError {}
