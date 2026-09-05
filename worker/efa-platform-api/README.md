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
stored as keyed HMACs (10-minute TTL, 5 attempts, per-purpose resend
cooldown: 10 minutes for verification, 60 seconds for reset) and delivered
via Resend (bilingual en/zh templates selected
by the optional `locale` field).

| Endpoint | Description |
| --- | --- |
| `/platform/auth/signup` | `{email, password, locale?}` — password 10–128 chars. `201 {userId}` for a new pending user + verification OTP; `200` (cooldown-respecting resend) for an existing pending one; `409 email_taken` when active. 5/h per IP, plus the shared OTP send limits: per purpose+address resend cooldown (10 min for verification, silent) and 10 sends/day per purpose+address (`429`) |
| `/platform/auth/signup/resend` | `{email, locale?}` — resends the verification OTP for a pending address without requiring the password. Always `200 {ok:true}` for unknown or active addresses (no enumeration); `429` with `Retry-After` when the pending address is inside its 10-minute resend cooldown or has exhausted the shared 10 verification sends/day per address. Shares the `/signup` 5/h per-IP budget |
| `/platform/auth/verify-email` | `{email, code}` — activates the pending user and issues a token pair (`200`); `401 otp_invalid`/`otp_expired`; `409 already_verified` |
| `/platform/auth/login` | `{email, password}` — `200` token pair; `403 email_unverified` (+ best-effort OTP resend, cooldown applies) when pending; uniform `401 invalid_credentials` otherwise. 5 failed attempts/30min per account+IP (successes are refunded), 30/5min per IP (loose on purpose: CGNAT) |
| `/platform/auth/refresh` | `{refreshToken}` — rotates the session (`200` new pair). Replaying the just-rotated token inside its ~60 s grace window returns the same successor pair (idempotent; a lost response must not log out mobile clients); replaying anything older revokes the whole session chain (`401 invalid_token`). 30 requests/5 min per IP (`429`, shared with `/logout`) |
| `/platform/auth/logout` | `{refreshToken}` — revokes that session; `200 {ok:true}` for any well-formed body, including unknown tokens (idempotent). Shares the `/refresh` IP limit: 30 requests/5 min per IP (`429`) |
| `/platform/auth/deregister` | Bearer access token + `{password}` (re-authentication: irreversible) — anonymizes the account (tombstone email, blanked hash, `token_version++`), revokes all sessions and clears their retained PII (`user_agent`, `ip`) in one atomic batch; `200 {ok:true}`; `401 invalid_credentials` on a wrong password; the address is free for re-signup. 5 failed attempts/30min per account+IP (successes are refunded) |
| `/platform/auth/account` | Bearer access token — authenticated account read: `200 {userId, email, roles, permissions}` where `roles` are the account's placeholder ACL roles (source of truth: `users.acl_roles`, schema and roles defined in `packages/efa_acl`) and `permissions` their resolved ACL tokens (served through the `AUTH_KV` resolved-permission cache) |
| `/platform/auth/reset-password` | `{email, locale?}` — always `200 {ok:true}` (no enumeration); sends a reset OTP when an active user exists (3/h per email, plus the shared OTP 60 s cooldown and 10/day cap, all enforced silently) |
| `/platform/auth/reset-password/confirm` | `{email, code, newPassword}` — updates the hash, bumps `token_version`, revokes all sessions, issues a fresh pair (`200`); `401` on invalid/expired OTP |

Rate-limit excess returns `429 {error:"rate_limited"}` with a `Retry-After`
header. Sessions live only in D1 (KV eventual consistency is incompatible
with rotation/reuse semantics); `AUTH_KV` holds the short-lived rotation
stash and the resolved-ACL permission cache (`acl:<userId>`, 5-minute TTL,
self-healing against the `users.acl_roles` source of truth). State that must be atomic — OTP consumption, OTP failure counts, and
rate-limit counters — lives in two SQLite-backed Durable Object classes
(`OtpState`, one instance per purpose+email; `RateLimitWindow`, one per
bucket+key), whose per-instance serialization plus single-transaction
read-modify-write removes the race KV's non-atomic updates had. Each
`OtpState` instance schedules its Durable Object alarm at the later of the
code expiry and the resend cooldown and `deleteAll()`s its storage when the
alarm fires, so abandoned (purpose, email) instances do not accumulate billed
SQLite storage. Idle
instances hibernate, which removes duration charges only while an object
qualifies for hibernation; requests and SQLite storage operations still
incur charges, so monitor usage against the plan's included Durable Object
allocations.

## API

Responses under `/platform/internal` carry `Access-Control-Allow-Origin: *`.
The `/platform/auth` mount instead answers CORS only for the platform's own
web origins (the allowlist in `src/root.ts`: the production and preview site
origins, the web app origins, and loopback dev origins), so arbitrary sites
cannot relay the token and email flows through a visitor's browser; clients
without an `Origin` header (the native app) are unaffected. Errors are JSON
`{ "error": <code>, "message": <string> }` with status 400 `bad_request`, 401
`invalid_token` (`unauthorized` is no longer used), 403 `forbidden` (ACL
permission missing), 404 `not_found`, 500
`internal`; errors from fit-storage are
passed through unchanged (e.g. 409 `snapshot_incomplete` — carrying
`latest_snapshot_hash` when a consented fallback candidate exists —, 422
`validation_failed`).

| Endpoint | Auth | Description |
| --- | --- | --- |
| `POST /platform/internal/posts` | account + `post:create` | Submit a `FitUploadRequest` protobuf body; stores the fit via the binding and inserts a post owned by the authenticated account. `201` JSON `{ postId, fitHash, alreadyExisted, snapshotHash, snapshotFallback, postUrl }` — `snapshotHash`/`snapshotFallback` report which data snapshot computed the fit (the two differ from the request when the uploader consented to the latest-snapshot fallback), and the post is bound to that variant. `postUrl` is the site's post page (`$PLATFORM_SITE_ORIGIN/post/<postId>`), so clients can redirect the user straight to it |
| `DELETE /platform/internal/posts/:id` | account + `post:delete:{own,all}` | Deletes the post row. `own` covers only the caller's own posts, `all` any post (qualifier validated against `posts.author_id` in the handler; NULL-author tombstones need `all`). The shared `fits` blob is unaffected. `200 { postId }`; 404 on unknown id |
| `GET /platform/internal/my/posts` | account | The caller's own posts; same keyset pagination contract and summary shape as the public list, minus the ship/window filters. `Cache-Control: no-store` |
| `GET /platform/internal/posts/:id` | public | JSON `{ postId, fitHash, createdAt, authorId, authorDeleted, commentCount }`; 400 on malformed UUID. `Cache-Control: public, max-age=60, stale-while-revalidate=300` — a deleted or edited post may serve stale within that window |
| `GET /platform/internal/posts/:id/snapshot` | public | Raw `FitSnapshot` protobuf bytes of the fit variant the post was created with, immutable cache |
| `GET /platform/internal/fits/:fitHash/snapshot` | public | Raw `FitSnapshot` protobuf bytes by fit hash, immutable cache; a fit hash may have several snapshot variants, the newest is served |
| `GET /platform/internal/fits/:fitHash/state` | public | Raw canonical `FitState` protobuf bytes by fit hash, immutable cache; identical across snapshot variants of a fit hash |
| `GET /platform/internal/posts` | public | Keyset-paginated list (`cursor`, `limit` ≤ 50, `locale`, `shipTypeId`, `window` = 24h/7d/30d/all); each summary carries `authorId`/`authorDeleted`. `Cache-Control: public, max-age=30, stale-while-revalidate=120` |
| `GET /platform/internal/ships` | public | Ship directory aggregated from `posts` (`q` name search, `window`, keyset `cursor`, `limit` ≤ 50, `locale`), `Cache-Control: public, max-age=30, stale-while-revalidate=120` |
| `GET /platform/internal/ships/:id` | public | Per-ship aggregate `{ shipTypeId, shipName, postCount, firstPostAt, lastPostAt }`; 404 when the ship has no posts. `Cache-Control: public, max-age=60, stale-while-revalidate=300` |
| `GET /platform/internal/stats` | public | Platform stats `{ totalPosts, distinctShips, postsLast7d, topShips }` (top ships by post count, names localized via `locale`). `Cache-Control: public, max-age=60, stale-while-revalidate=300` |
| `GET /platform/internal/posts/:id/comments` | public | The post's discussion comments, oldest-first (`cursor`, `limit` ≤ 100); each comment carries `{ commentId, authorId, authorDeleted, body, createdAt }` with `body` as raw markdown. `Cache-Control: public, max-age=30, stale-while-revalidate=60` |
| `POST /platform/internal/posts/:id/comments` | account + `comment:create` | JSON `{ body }` (markdown, trimmed, 1–10 000 code points). `201` with the created comment; 404 on unknown post |
| `DELETE /platform/internal/comments/:id` | account + `comment:delete:{own,all}` | Deletes the comment row; same qualifier contract as post deletion. `200 { commentId }`; 404 on unknown id |
| `GET /platform/internal/health` | public | `{ "ok": true }`; a valid Bearer token additionally pings D1 and the fit-storage binding. `Cache-Control: no-store` — probes must report live state |

Public reads are unauthenticated; post creation and deletion require an
account access token (`Authorization: Bearer <accessToken>`, verified with
the same active-status and `token_version` re-check as
`/platform/auth/deregister`; failures return `401 invalid_token`) plus an ACL
permission. The `requirePermission` middleware (`src/auth/permission.ts`)
resolves the account's roles into tokens (through the `AUTH_KV` cache) and
performs the action-level match: unqualified actions (`post:create`) need the
exact token, qualified actions (`post:delete`) pass with any qualifier and
the handler validates the qualifier against the resource (`own` = the
caller authors the post, `all` = any post). A missing permission returns
`403 forbidden`. The shared `FIT_STORAGE_TOKEN` bearer
no longer gates uploads — it only unlocks the privileged `/health` probes.
Binding calls between this worker and fit-storage are account-internal and
unauthenticated.

Post ownership: every post records its uploading account in
`posts.author_id`. `authorId` is the account's user id, or `null` when the
author is a tombstone; `authorDeleted` is `true` when `authorId` is `null`
**or** the author row is deregistered (anonymized). Account deletion never
removes posts: deregistration anonymizes the user row in place, and a hard
user delete nulls the reference (`ON DELETE SET NULL`) — either way the post
survives with `authorDeleted: true`. Deleting a post is a plain row drop with
no effect on users, gated by the `post:delete:{own,all}` ACL tokens (above).

Discussion comments follow the same ownership and tombstone rules
(`comments.author_id`, `ON DELETE SET NULL`); deleting a post cascades to its
comments (`ON DELETE CASCADE`). Comment bodies are stored as raw markdown —
rendering and sanitizing are the client's job.
Posts created before accounts existed were migrated with
`author_id = NULL` and read as tombstones.

## Data model

One physical D1 database (`efa-platform`) with disjoint table ownership:
`posts` is written only here (`migrations/0001_posts.sql`,
`0004_post_author.sql` adds the `author_id` foreign key into `users`);
`fits` is written
only by `efa-platform-fit-storage`; the auth tables (`users`, `auth_sessions`,
`migrations/0003_auth.sql`) are written only here. Migration filenames must
never collide across the two workers — wrangler records applied filenames per
database.

The list endpoint is pure SQL over `posts` plus a `LEFT JOIN` to `users` to
calculate author deletion status (`authorId`/`authorDeleted`): the display
summary is denormalized at post creation (`description` truncated to 280 code
points, `ship_names` a JSON locale map), so the read path does no blob
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

> [!NOTE]
> The named preview environment (`efa-platform-api-preview.*.workers.dev`) is
> protected by Cloudflare Access. (Cloudflare does not generate per-deploy
> preview URLs or preview aliases for Workers that implement Durable Objects.)
> A bare `curl` gets the Access login page, not the API.
> Authenticate from the CLI with `cloudflared`, then call through it:
>
> ```sh
> cloudflared access login https://efa-platform-api-preview.<subdomain>.workers.dev
> # wrapper that injects the token automatically:
> cloudflared access curl https://efa-platform-api-preview.<subdomain>.workers.dev/platform/internal/health
> # or export the token for plain curl:
> export TOKEN=$(cloudflared access token -app=https://efa-platform-api-preview.<subdomain>.workers.dev)
> curl -H "cf-access-token: $TOKEN" https://efa-platform-api-preview.<subdomain>.workers.dev/platform/internal/health
> ```
>
> The token is valid for the session duration configured on the Access
> application; re-run `access login` after it expires. See the official guide:
> <https://developers.cloudflare.com/cloudflare-one/tutorials/cli/>.

## Deployment (one-time setup)

1. Apply migrations: `wrangler d1 migrations apply efa-platform --remote`
   for the default environment and `wrangler d1 migrations apply efa-platform-test
   --remote --env preview` for the preview environment.
2. Create the auth KV namespaces (rotation stash plus the `acl:<userId>`
   resolved-permission cache): `wrangler kv namespace create
   efa-platform-auth` for the default environment and `wrangler kv namespace create
   efa-platform-auth --env preview` for the preview environment, then paste the
   IDs into `wrangler.toml` (`[[kv_namespaces]]` and
   `[[env.preview.kv_namespaces]]`). Note: `--preview` selects a KV preview
   namespace; it does not select `[env.preview]` — use `--env preview`.
   The Durable Object classes need no manual provisioning: the `v1`
   `new_sqlite_classes` migration in `wrangler.toml` creates them at deploy
   time (and again on the first `--env preview` deploy).
3. `wrangler secret put FIT_STORAGE_TOKEN` (re-provision the existing value),
   `wrangler secret put AUTH_TOKEN_SECRET` (JWT/OTP HMAC key), and
   `wrangler secret put RESEND_API_KEY` — run each once for the default
   environment and once with `--env preview`.
4. Verify the `platform.efa-tech.dev` sender subdomain in Resend (DKIM/SPF DNS
   records). The sender address itself is the plain `EMAIL_FROM` var.
5. `wrangler deploy`. Workers are deployed manually; no CI deploys exist.
