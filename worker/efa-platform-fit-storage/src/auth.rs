use worker::{Env, Request};

use crate::error::ApiError;

/// Constant-time string equality over UTF-8 bytes: length check, then
/// XOR-accumulate with no early exit. Port of `timingSafeEqual` in
/// `worker/efa-platform-data-sync/src/index.ts`.
fn timing_safe_equal(a: &str, b: &str) -> bool {
    let a = a.as_bytes();
    let b = b.as_bytes();
    if a.len() != b.len() {
        return false;
    }
    let mut diff = 0u8;
    for i in 0..a.len() {
        diff |= a[i] ^ b[i];
    }
    diff == 0
}

/// Bearer-token check for non-public endpoints (spec §6.1). The token is a
/// wrangler secret; a missing secret is a server misconfiguration (500).
pub fn check_authorization(req: &Request, env: &Env) -> Result<(), ApiError> {
    let secret = env
        .secret("FIT_STORAGE_TOKEN")
        .map_err(|_| ApiError::internal("FIT_STORAGE_TOKEN is not set"))?;
    let token = secret.to_string();

    let header = req
        .headers()
        .get("Authorization")
        .map_err(|e| ApiError::internal(format!("failed to read headers: {e}")))?
        .unwrap_or_default();
    if !timing_safe_equal(&header, &format!("Bearer {token}")) {
        return Err(ApiError::unauthorized());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::timing_safe_equal;

    #[test]
    fn constant_time_equality() {
        assert!(timing_safe_equal("Bearer abc", "Bearer abc"));
        assert!(!timing_safe_equal("Bearer abc", "Bearer abd"));
        assert!(!timing_safe_equal("Bearer abc", "Bearer abcd"));
        assert!(!timing_safe_equal("", "x"));
        assert!(timing_safe_equal("", ""));
    }
}
