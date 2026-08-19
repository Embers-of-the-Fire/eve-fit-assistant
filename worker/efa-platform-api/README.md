# efa-platform-api

Public front of the platform: a Cloudflare Worker (TypeScript) shared by the
discussion site (`site/platform`) and the Flutter app. It owns the `posts`
table, orchestrates submissions through the `FIT_STORAGE` service binding of
`efa-platform-fit-storage`, and serves all public endpoints under
`api.efa-tech.dev/platform/internal/*`.

Spec: `docs/temp/api-unit/spec.md` §6.

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
| `GET /platform/internal/posts` | public | Keyset-paginated list (`cursor`, `limit` ≤ 50, `locale`), `Cache-Control: public, max-age=30` |
| `GET /platform/internal/posts/:id/threads` | public | Stub: `{ "threads": [] }` |
| `GET /platform/internal/health` | public | `{ "ok": true }`; a valid Bearer token additionally pings D1 and the fit-storage binding |

Public reads are unauthenticated; post creation requires
`Authorization: Bearer <FIT_STORAGE_TOKEN>` (constant-time comparison).
Binding calls between this worker and fit-storage are account-internal and
unauthenticated.

## Data model

One physical D1 database (`efa-platform`) with disjoint table ownership:
`posts` is written only here (`migrations/0001_posts.sql`); `fits` is written
only by `efa-platform-fit-storage`. Migration filenames must never collide
across the two workers — wrangler records applied filenames per database.

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

`wrangler deploy --env preview` targets the `[env.preview]` chain
(`docs/temp/api-unit/spec.md` §4.4): `FIT_DB` points at the disposable
`efa-platform-test` database and the `FIT_STORAGE` binding targets the
`preview` environment of `efa-platform-fit-storage`.

## Deployment (one-time setup)

1. Apply migrations: `wrangler d1 migrations apply efa-platform --remote`
   (and `--env preview` for `efa-platform-test`).
2. `wrangler secret put FIT_STORAGE_TOKEN` (re-provision the existing value).
3. `wrangler deploy`. Workers are deployed manually; no CI deploys exist.
