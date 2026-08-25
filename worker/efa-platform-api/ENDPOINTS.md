# Auth API schema

Base URL: `https://api.efa-tech.dev/platform/auth`. All endpoints are `POST`
with JSON request and response bodies (`Content-Type: application/json`).
Tokens are transported in response bodies; there are no cookies. Cross-origin
browser access is restricted to the platform's own web origins (the allowlist
in `src/root.ts`); non-browser clients send no `Origin` header and are
unaffected.

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
  SHA-256 hash is stored server-side (the sole plaintext copy is the ~61 s
  rotation stash in `AUTH_KV`, kept so a replayed rotation inside the grace
  window returns the same pair).
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
- `200 { "ok": true }` — email already pending; code resent unless the
  10-minute resend cooldown is active (then nothing is sent). The submitted
  password is ignored: the account keeps the password from the initial
  signup.
- `409 email_taken` — an active account with this email exists.
- `429 rate_limited` — 5 signups/hour per IP, or 10 OTP sends/day per
  purpose+address.

### `/signup/resend`

Resends the verification code for a pending account without requiring the
password (a repeat `/signup` needs one even though it is ignored), for the
register flow's verification step.

Request: `{ email: string, locale?: string }`

Responses:

- `200 { "ok": true }` — code resent. Also returned for unknown or active
  addresses without sending anything (enumeration-safe).
- `429 rate_limited` — the address is pending but inside its 10-minute
  resend cooldown (`Retry-After` carries the remaining seconds), the
  per-address daily OTP cap is exhausted, or the per-IP budget (5/hour,
  shared with `/signup`) is exceeded.

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
- `429 rate_limited` — 5 failed logins/30 min per account+IP (successful
  logins are refunded and never consume quota) or 30/5 min per IP (the IP
  limit is deliberately loose: mobile carriers share exit IPs via CGNAT).

### `/refresh`

Rotates a refresh token.

Request: `{ refreshToken: string }`

Responses:

- `200` token pair — the presented token is invalidated and replaced.
- `401 invalid_token` — unknown, expired, or revoked token.
- `429 rate_limited` — 30 requests/5 min per IP (shared with `/logout`).

Rotation semantics:

- Presenting the immediately-previous token within its ~60 s grace window
  returns the *same* successor pair (idempotent replay — a response lost after
  server-side rotation must not log the client out).
- Concurrent rotations of the same token resolve to a single successor: the
  rotation claim is atomic, so the losing request follows the replay path
  above instead of minting a competing session.
- Presenting a rotated-out token after its grace window is treated as theft:
  the account's entire session chain is revoked and the call returns `401`.

### `/logout`

Request: `{ refreshToken: string }`

Responses:

- `200 { "ok": true }` — for any well-formed body within the rate limit,
  including unknown tokens (idempotent).
- `400 bad_request` — malformed body.
- `429 rate_limited` — 30 requests/5 min per IP (shared with `/refresh`).

### `/deregister`

Anonymizes the account and revokes all credentials. Irreversible, so it
re-authenticates: the current password is required on top of the access token.

Request: `{ password: string }`; requires `Authorization: Bearer <accessToken>`.

Responses:

- `200 { "ok": true }` — the email is tombstoned
  (`deleted-<user_id>@deregistered.invalid`), the password hash blanked, the
  token version bumped, and every session revoked with its retained PII
  (`user_agent`, `ip`) cleared — all in one atomic batch. The address is
  immediately free for re-signup.
- `400 bad_request` — malformed body (missing `password`).
- `401 invalid_token` — missing/invalid/expired access token, or a stale token
  version.
- `401 invalid_credentials` — wrong password.
- `429 rate_limited` — 5 failed attempts/30 min per account+IP (successful
  calls are refunded and never consume quota).

### `/account`

Authenticated account read: identity plus the account's placeholder ACL roles
and their resolved permission tokens (schema and roles: `packages/efa_acl`).
Roles are stored on the account row (`users.acl_roles`, source of truth); the
resolved token set is served through the `AUTH_KV` cache
(`acl:<userId>`, 5-minute TTL, self-healing on role divergence).

Request: `{}`; requires `Authorization: Bearer <accessToken>`.

Responses:

- `200 { "userId": string, "email": string, "roles": string[],
  "permissions": string[] }` — `permissions` is the union of the roles' ACL
  tokens (`{domain}:{action}[:{qualifier}]`). `roles` is self-view only:
  clients must treat role names as opaque internal identifiers (label-map them
  before display) and gate UI exclusively on `permissions`.
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
| `signup` per IP | 5 / hour (shared with `/signup/resend`) |
| Verification OTP sends per address | 10 min cooldown + 10 / day |
| Reset OTP sends per address | 60 s cooldown + 10 / day |
| OTP verify attempts | 5 per issued code |
| `login` per account+IP | 5 failures / 30 min |
| `login` per IP | 30 / 5 min |
| `refresh`/`logout` per IP | 30 / 5 min |
| `deregister` per account+IP | 5 failures / 30 min |
| `reset-password` per address | 3 / hour |
