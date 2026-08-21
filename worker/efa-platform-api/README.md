# efa-platform-api

Public front of the platform: a Cloudflare Worker (TypeScript) shared by the
discussion site (`site/platform`) and the Flutter app. It owns the `posts`
table, orchestrates submissions through the `FIT_STORAGE` service binding of
`efa-platform-fit-storage`, serves all public endpoints under
`api.efa-tech.dev/platform/internal/*`, and hosts the platform's email+password
authentication backend under `api.efa-tech.dev/platform/auth/*`.

## Auth API

All auth endpoints are `POST` with JSON request/response bodies and share the
platform error envelope. [ENDPOINTS.md](ENDPOINTS.md) is the canonical
request/response schema reference. Tokens are transported in JSON bodies (no cookies).
Passwords are PBKDF2-HMAC-SHA256 hashes; access tokens are 15-minute HS256
JWTs carrying a `tv` (token version) claim checked against `users.token_version`
on authenticated calls; refresh tokens are opaque 30-day tokens rotated on
every refresh, with only their SHA-256 hash stored. One exception: the
rotation stash in `AUTH_KV` keeps the just-issued successor pair in plaintext
for ~61 s so a replayed rotation inside the 60 s grace window returns the same
pair. OTPs are 6-digit codes
stored as keyed HMACs (10-minute TTL, 5 attempts, 60-second
resend cooldown) and delivered via Resend (bilingual en/zh templates selected
by the optional `locale` field).

| Endpoint | Description |
| --- | --- |
| `/platform/auth/signup` | `{email, password, locale?}` — password 10–128 chars. `201 {userId}` for a new pending user + verification OTP; `200` (cooldown-respecting resend) for an existing pending one; `409 email_taken` when active. 5/h per IP |
| `/platform/auth/verify-email` | `{email, code}` — activates the pending user and issues a token pair (`200`); `401 otp_invalid`/`otp_expired`; `409 already_verified` |
| `/platform/auth/login` | `{email, password}` — `200` token pair; `403 email_unverified` (+ best-effort OTP resend) when pending; uniform `401 invalid_credentials` otherwise. 20/day per account, 30/5min per IP (loose on purpose: CGNAT) |
| `/platform/auth/refresh` | `{refreshToken}` — rotates the session (`200` new pair). Replaying the just-rotated token inside its ~60 s grace window returns the same successor pair (idempotent; a lost response must not log out mobile clients); replaying anything older revokes the whole session chain (`401 invalid_token`) |
| `/platform/auth/logout` | `{refreshToken}` — revokes that session; always `200 {ok:true}` |
| `/platform/auth/deregister` | Bearer access token — anonymizes the account (tombstone email, blanked hash, `token_version++`), revokes all sessions; `200 {ok:true}`; the address is free for re-signup |
| `/platform/auth/reset-password` | `{email, locale?}` — always `200 {ok:true}` (no enumeration); sends a reset OTP when an active user exists (3/h per email) |
| `/platform/auth/reset-password/confirm` | `{email, code, newPassword}` — updates the hash, bumps `token_version`, revokes all sessions, issues a fresh pair (`200`); `401` on invalid/expired OTP |

Rate-limit excess returns `429 {error:"rate_limited"}` with a `Retry-After`
header. Sessions live only in D1 (KV eventual consistency is incompatible
with rotation/reuse semantics); `AUTH_KV` holds only the short-lived rotation
stash. State that must be atomic — OTP consumption, OTP failure counts, and
rate-limit counters — lives in two SQLite-backed Durable Object classes
(`OtpState`, one instance per purpose+email; `RateLimitWindow`, one per
bucket+key), whose per-instance serialization plus single-transaction
read-modify-write removes the race KV's non-atomic updates had. Idle
instances hibernate (no duration charge), so at authentication volume the
metered cost stays within the included Durable Object allocations.

## API

All public responses carry `Access-Control-Allow-Origin: *`. Errors are JSON
`{ "error": <code>, "message": <string> }` with status 400 `bad_request`, 401
`unauthorized`, 404 `not_found`, 500 `internal`; errors from fit-storage are
passed through unchanged (e.g. 409 `snapshot_incomplete`, 422
`validation_failed`).

| Endpoint | Auth | Description |
| --- | --- | --- |
| `POST /platform/internal/posts` | Bearer | Submit a `FitUploadRequest` protobuf body; stores the fit via the binding and inserts a post. `201` JSON `{ postId, fitHash, alreadyExisted }` |
| `GET /platform/internal/posts/:id` | public | JSON `{ postId, fitHash, createdAt }`; 400 on malformed UUID |
| `GET /platform/internal/posts/:id/snapshot` | public | Raw `FitSnapshot` protobuf bytes, immutable cache |
| `GET /platform/internal/fits/:fitHash/snapshot` | public | Raw `FitSnapshot` protobuf bytes by fit hash, immutable cache |
| `GET /platform/internal/posts` | public | Keyset-paginated list (`cursor`, `limit` ≤ 50, `locale`, `shipTypeId`, `window` = 24h/7d/30d/all), `Cache-Control: public, max-age=30` |
| `GET /platform/internal/ships` | public | Ship directory aggregated from `posts` (`q` name search, `window`, keyset `cursor`, `limit` ≤ 50, `locale`), `max-age=30` |
| `GET /platform/internal/ships/:id` | public | Per-ship aggregate `{ shipTypeId, shipName, postCount, firstPostAt, lastPostAt }`; 404 when the ship has no posts |
| `GET /platform/internal/posts/:id/threads` | public | Stub: `{ "threads": [] }` |
| `GET /platform/internal/health` | public | `{ "ok": true }`; a valid Bearer token additionally pings D1 and the fit-storage binding |

Public reads are unauthenticated; post creation requires
`Authorization: Bearer <FIT_STORAGE_TOKEN>` (constant-time comparison).
Binding calls between this worker and fit-storage are account-internal and
unauthenticated.

## Data model

One physical D1 database (`efa-platform`) with disjoint table ownership:
`posts` is written only here (`migrations/0001_posts.sql`); `fits` is written
only by `efa-platform-fit-storage`; the auth tables (`users`, `auth_sessions`,
`migrations/0003_auth.sql`) are written only here. Migration filenames must
never collide across the two workers — wrangler records applied filenames per
database.

The list endpoint is pure SQL over `posts`: the display summary is
denormalized at post creation (`description` truncated to 280 code points,
`ship_names` a JSON locale map), so the read path does no joins or blob
decodes.

## Local development

```sh
./build.sh        # pnpm install + proto bindings + tsc check
pnpm --filter efa-platform-api dev      # wrangler dev (miniflare D1)
pnpm --filter efa-platform-api check    # tsc --noEmit
pnpm --filter efa-platform-api lint     # biome check --write src/
```

Local secrets: copy `.dev.vars.example` to `.dev.vars` and set a token.

## Preview environment

`wrangler deploy --env preview` targets the `[env.preview]` preview chain:
`FIT_DB` points at the disposable
`efa-platform-test` database and the `FIT_STORAGE` binding targets the
`preview` environment of `efa-platform-fit-storage`.

## Deployment (one-time setup)

1. Apply migrations: `wrangler d1 migrations apply efa-platform --remote`
   (and `--env preview` for `efa-platform-test`).
2. Create the auth KV namespace (rotation stash only): `wrangler kv namespace create
   efa-platform-auth` (plus a preview namespace) and paste the IDs into
   `wrangler.toml` (`[[kv_namespaces]]` and `[[env.preview.kv_namespaces]]`).
   The Durable Object classes need no manual provisioning: the `v1`
   `new_sqlite_classes` migration in `wrangler.toml` creates them at deploy
   time (and again on the first `--env preview` deploy).
3. `wrangler secret put FIT_STORAGE_TOKEN` (re-provision the existing value),
   `wrangler secret put AUTH_TOKEN_SECRET` (JWT/OTP HMAC key), and
   `wrangler secret put RESEND_API_KEY` — each for the default and `preview`
   environments.
4. Verify the `platform.efa-tech.dev` sender subdomain in Resend (DKIM/SPF DNS
   records). The sender address itself is the plain `EMAIL_FROM` var.
5. `wrangler deploy`. Workers are deployed manually; no CI deploys exist.
