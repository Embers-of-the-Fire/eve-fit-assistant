# Auth API schema

Base URL: `https://api.efa-tech.dev/platform/auth`. All endpoints are `POST`
with JSON request and response bodies (`Content-Type: application/json`).
Tokens are transported in response bodies; there are no cookies.

## Common shapes

### Token pair

Returned by `verify-email`, `login`, `refresh`, and `reset-password/confirm`.

```json
{
    "accessToken": "<JWT>",
    "refreshToken": "<43-char base64url>",
    "expiresIn": 900
}
```

- `accessToken`: HS256 JWT, 15-minute TTL, claims `{sub, iat, exp, jti, tv}`
  (`tv` is the account's token version, checked on authenticated calls).
- `refreshToken`: opaque, 30-day TTL, rotated on every `refresh`; only its
  SHA-256 hash is stored server-side.
- `expiresIn`: access-token lifetime in seconds.

### Error envelope

```json
{
    "error": "<code>",
    "message": "<human-readable string>"
}
```

| Status | Codes used |
| --- | --- |
| 400 | `bad_request` — malformed JSON or schema violation |
| 401 | `invalid_credentials`, `otp_invalid`, `otp_expired`, `invalid_token` |
| 403 | `email_unverified` |
| 409 | `email_taken`, `already_verified` |
| 429 | `rate_limited` — always with a `Retry-After: <seconds>` header |
| 500 | `internal` |

## Endpoints

### `/signup`

Registers a pending account and sends a 6-digit verification code.

Request: `{ email: string, password: string, locale?: string }`

- `email` is trimmed and lowercased before use; must be a valid address.
- `password` must be 10–128 characters.
- `locale` selects the email language (`"zh*"` → Chinese, default English).

Responses:

- `201 { "userId": "<uuid>" }` — pending user created, code sent.
- `200 { "ok": true }` — email already pending; code resent unless the 60 s
  resend cooldown is active (then nothing is sent).
- `409 email_taken` — an active account with this email exists.
- `429 rate_limited` — 5 signups/hour per IP, or 10 OTP sends/day per address.

### `/verify-email`

Activates a pending account and logs it in.

Request: `{ email: string, code: string }` — `code` is exactly 6 digits.

Responses:

- `200` token pair — account activated.
- `401 otp_invalid` — wrong code (at most 5 attempts per issued code).
- `401 otp_expired` — no live code for this address (never issued, older than
  10 minutes, or burned by failed attempts); also returned for unknown emails.
- `409 already_verified` — account is already active.

### `/login`

Request: `{ email: string, password: string }`

Responses:

- `200` token pair.
- `401 invalid_credentials` — unknown email or wrong password (uniform by
  design).
- `403 email_unverified` — account is pending; a fresh verification code is
  resent best-effort (cooldown applies).
- `429 rate_limited` — 20 logins/day per account or 30/5 min per IP (the IP
  limit is deliberately loose: mobile carriers share exit IPs via CGNAT).

### `/refresh`

Rotates a refresh token.

Request: `{ refreshToken: string }`

Responses:

- `200` token pair — the presented token is invalidated and replaced.
- `401 invalid_token` — unknown, expired, or revoked token.

Rotation semantics:

- Presenting the immediately-previous token within its ~60 s grace window
  returns the *same* successor pair (idempotent replay — a response lost after
  server-side rotation must not log the client out).
- Presenting a rotated-out token after its grace window is treated as theft:
  the account's entire session chain is revoked and the call returns `401`.

### `/logout`

Request: `{ refreshToken: string }`

Responses:

- `200 { "ok": true }` — always, including for unknown tokens (idempotent).
- `400 bad_request` — malformed body.

### `/deregister`

Anonymizes the account and revokes all credentials.

Request: no body; requires `Authorization: Bearer <accessToken>`.

Responses:

- `200 { "ok": true }` — the email is tombstoned
  (`deleted-<user_id>@deregistered.invalid`), the password hash blanked, the
  token version bumped, and every session revoked. The address is immediately
  free for re-signup.
- `401 invalid_token` — missing/invalid/expired access token, or a stale token
  version.

### `/reset-password`

Requests a password-reset code. Enumeration-safe by construction.

Request: `{ email: string, locale?: string }`

Responses:

- `200 { "ok": true }` — always. A code is sent only when an active account
  exists; at most 3 reset emails/hour per address (plus the generic OTP
  cooldown and daily cap), all enforced silently.

### `/reset-password/confirm`

Request: `{ email: string, code: string, newPassword: string }` —
`newPassword` follows the same 10–128 character policy.

Responses:

- `200` token pair — password updated, token version bumped, all prior
  sessions revoked; the returned pair is the only surviving credential.
- `401 otp_invalid` / `401 otp_expired` — wrong, expired, or missing code
  (also for unknown or non-active emails).

## Rate-limit summary

Exceeded limits return `429 { "error": "rate_limited" }` with `Retry-After`.

| Bucket | Limit |
| --- | --- |
| `signup` per IP | 5 / hour |
| OTP sends per purpose+address | 60 s cooldown + 10 / day |
| OTP verify attempts | 5 per issued code |
| `login` per account | 20 / day |
| `login` per IP | 30 / 5 min |
| `reset-password` per address | 3 / hour |
