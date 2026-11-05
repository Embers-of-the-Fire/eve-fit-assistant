# Remote Content

This document records the local processing paths that remote content delivery
reuses, plus the remote storage contracts. The first sections cover local data
bundle generation and the mock launcher; the later sections define the version 1
and version 2 remote content storage contracts.

## Data Bundle Generation

Data is generated from the selected workspace through `./x`.

- `./x build data` runs the full workspace data generator for the selected workspace.
- The generator writes a V2 resource snapshot under the schema root (default
  `cache/schema/`): a content-addressed blob store at
  `assets/blobs/{2c}/{ident_hash}/{content_hash}` plus an immutable snapshot at
  `assets/resources/<snapshot_hash>/` holding `metadata.json` (server metadata) and
  `resources.pb2` (resource index).

The snapshot is produced by `bootstrap/data/workspace/generate/schema.py`
(`generate_resource_snapshot`). The resource index carries the content-addressed file
manifest (resource ID, content hash, and size per entry), and `metadata.json` carries
server metadata from workspace configuration. The reported `<snapshot_hash>` is the v4
structured hash binding both files (see `bootstrap/remote/hash.py`), not a
sorted-manifest digest; the legacy `generate_schema_checkout` wrapper returns the same
resource snapshot hash.

## Local Remote Mock Launcher

The repository provides a local mock origin for manual remote endpoint integration. The mock provides
the storage layout; app-side consumption is implemented by the follow-up remote sync work.

Launch the S3-compatible RustFS mock (the only supported mock backend):

```bash
./x remote mock launch --daemon
```

`launch` runs in the foreground by default; `--daemon` detaches after startup so the
staging and publishing commands below can run in the same terminal (stop it later with
`./x remote mock stop`). Without `--daemon`, run the remaining commands in a separate
terminal while the mock keeps running.

The launcher reuses the persisted store under the mock data directory, so content from
prior runs remains; run `./x remote mock clean` first for a completely empty store.
Content reaches the mock through session staging and
`publish` (below), not from a copied fixture tree. The committed fixture tree at
`docs/examples/remote/mock-origin/` is a reference layout only.

Default mock endpoints after publishing a channel head:

```text
http://127.0.0.1:9000/efa-dev/efa/v2/channels/heads/channels.json
http://127.0.0.1:9000/efa-dev/efa/v2/channels/heads/testing/metadata.json
```

Android emulator mock origin URL:

```text
http://10.0.2.2:9000/efa-dev
```

Inspect effective remote mock configuration:

```bash
./x remote config display --pretty
```

Start a staging session, then stage the generated resource snapshot for publishing after
running the data build. A fresh schema root has no active session, so the first
`session add` fails with `No active session` until one is initialized:
```bash
./x remote session init <channel>
./x remote session add --resource --hash <snapshot_hash>
./x remote session commit --allow-empty-release-pointer
```

`--allow-empty-release-pointer` is required only for this resource-only first commit: a
root generation has no parent generation to inherit a release pointer from, and
`session commit` otherwise refuses to commit it. Later commits inherit the release
pointer from the parent generation, so a plain `session commit` suffices.

`session add` only stages the snapshot; `publish` uploads the channel's committed head.
Commit before publishing: with no head, `publish` returns without uploading anything yet
still prints `Publish complete.`; with an older head, it uploads that older generation and
omits the staged snapshot. Use a plain `session commit` — `--no-push` skips the push that
advances the head.

## Remote Bundle Mock Artifacts

The launcher reads defaults from `efa.dev.toml`, with CLI arguments taking precedence for a single
invocation. Configure the default ports, bucket, credentials, channel, resource root, mock origin
directory, and mock data directory in the `[remote]` and `[remote.mock]` sections of
`efa.dev.toml`. The default mock data directory is `cache/remote/mock-data/`, so object storage
persists across launcher restarts.

Upload a committed channel head to an already running mock or S3-compatible endpoint:

```bash
./x remote publish <channel> --target mock
```

The publish command uses the same `[remote]` defaults as the mock launcher. It uploads the
head generation plus the resource and release snapshots that changed from the channel's
parent generation (and their blobs) to the target bucket with content-addressed immutable
paths, then moves the channel head pointer. Snapshots inherited unchanged from the parent
generation are skipped — the destination is expected to already contain them. Publishing an
existing channel to a fresh mock or bucket therefore does not populate the inherited
objects; the full chain must have reached the destination previously. Two cases relax this
rule: the publisher re-uploads an unchanged release snapshot when its remote
`releases.pb2` is missing, so the head never points at a dangling release index; and when
the recorded parent generation is not available locally, it cannot diff against it and
treats every snapshot referenced by the head as changed, uploading them again (blobs
already present on the remote are still skipped).
If interrupted, retry is safe and idempotent — blobs already on the remote are skipped.

Useful publishing overrides:

```bash
./x remote publish testing --target mock --endpoint http://127.0.0.1:9000 --bucket efa-dev
./x remote publish testing --target s3 --endpoint https://example-r2-or-oss-endpoint --bucket efa-prod
```

Useful overrides:

```bash
./x remote mock launch --port 9100 --console-port 9101 --bucket efa-test
./x remote mock launch --data-dir cache/remote/alternate-mock
```

The mock launcher uses local development credentials only. Production R2, OSS, or S3-compatible
credentials belong in release tooling and must not be shipped in the app.

## Remote Checkout Mock Artifacts

To test remote data checkout downloads locally:

1. Build data for a configured workspace:

   ```bash
   ./x build data
   ```

2. Start a new session and stage the generated resource snapshot in it:

   ```bash
   ./x remote session init <channel> --force-overwrite
   ./x remote session add --resource --hash <snapshot_hash>
   ```

   The earlier session cannot be reused: a committed session removes its session file,
   so `session add` fails with `No active session`; an uncommitted session already
   contains that server, so the duplicate-server rule rejects the add. Re-running
   `init` while the earlier session is still uncommitted stops with
   `SessionExistsError`, hence `--force-overwrite`.

3. Launch the RustFS mock:

   ```bash
   ./x remote mock launch
   ```

4. Commit the session and publish the channel head to the mock:

   ```bash
   ./x remote session commit --allow-empty-release-pointer
   ./x remote publish <channel> --target mock
   ```

   The flag is only needed for a resource-only first commit on a schema root with no
   parent generation; once the channel has a committed release pointer, a plain
   `session commit` works.

The V2 client recomputes the v4 structured snapshot hash over the downloaded
`metadata.json` and `resources.pb2`, but `CheckoutService.applyDataUpdate` never
compares that local hash against the advertised `newSnapshotHash` — the recomputed
hash simply becomes the snapshot's new local identity, so a changed index fetched
under the advertised hash is accepted as-is. This resource-download path has no
catalog `appVersion` check. Snapshot `gameRegion` in `metadata.json` is metadata
only and is not used for client-side filtering.

## V1 Storage Contract

This section defines the version 1 remote content storage contract for EVE Fit
Assistant. The contract is designed for static HTTP and S3-compatible object storage,
including Cloudflare R2, Alibaba OSS, RustFS, and CDN-backed buckets.

The v1 storage contract covers:

- Remote document catalogs, announcements, information entries, version notes, and Markdown bodies.
- App release metadata for user-facing update notices.
- Data bundle discovery metadata, bundle archives, and bundle manifest snapshots.
- Local static mocks that use the same object layout as production storage.

The v1 storage contract does not cover:

- In-app binary hot updates.
- Runtime packages or xapp-like packages.
- Dynamic Dart, native library, or JavaScript replacement.
- Object storage credentials in the app.
- Any requirement for a dynamic application server.

### Versioned Storage Model

Remote content is addressed as static objects under a public origin and a versioned resource root:

```text
<originUrl>/<resourceRoot>/
```

For this contract, the resource root is:

```text
efa/v1/
```

`v1` is the storage and wire-schema version. It is separate from content channels such as `testing`
or `stable`. Breaking changes to object layout, JSON semantics, or required fields must use a new
resource root such as `efa/v2/`.

### Endpoint Configuration Semantics

Clients conceptually need these fields to locate remote content:

```json
{
  "enabled": false,
  "originUrl": "https://updates.example.com/",
  "resourceRoot": "efa/v1/",
  "channel": "testing",
  "region": "global"
}
```

Field semantics:

- `enabled`: whether the client should attempt remote content discovery.
- `originUrl`: public static storage origin, CDN URL, bucket URL, R2/OSS custom domain, or local
  mock origin. It may include a bucket path, such as a local mock bucket prefix.
- `resourceRoot`: versioned resource prefix. For v1, this is `efa/v1/`.
- `channel`: content stream selected by the client.
- `region`: optional storage or S3-compatible deployment region metadata, such as `global`, `cn`,
  or a provider-specific region name. It is not a bundle artifact compatibility filter.

URL joining must be deterministic. Clients and publishers should treat `originUrl` as the only
component allowed to carry an optional trailing slash, then trim any trailing slash before appending
`resourceRoot` and relative paths. `resourceRoot` and all relative payload paths must not start with
`/`. This avoids double-slash paths such as `https://updates.example.com//efa/v1/...`, which can be
resolved differently by strict object storage backends, CDNs, and HTTP clients.

The effective channel index URL is:

```text
<trimTrailingSlash(originUrl)>/<resourceRoot>channels/<channel>/index.json
```

Example:

```text
https://updates.example.com/efa/v1/channels/testing/index.json
```

### Canonical Object Layout (V1)

The canonical v1 object layout is:

```text
efa/v1/channels/<channel>/index.json
efa/v1/channels/<channel>/.generations/<generation>/documents/catalog.json
efa/v1/channels/<channel>/.generations/<generation>/app/releases.json
efa/v1/channels/<channel>/.generations/<generation>/bundles/catalog.json
efa/v1/documents/body/<locale>/<document-id>.md
efa/v1/bundles/<bundle-id>/<artifact-id>.zip
efa/v1/bundles/<bundle-id>/<artifact-id>.manifest.json
```

The live channel `index.json` is mutable metadata. Generation-stamped catalog objects, document
body objects, and bundle objects should be treated as immutable.

### Channel Semantics

Channels are content streams, not API versions. Two channels are defined:

```text
testing
stable
```

- **testing** — bleeding-edge data for developers and early testers. May contain incomplete content,
  internal-only announcements, and experimental bundles.  Updated frequently.
- **stable** — validated data for normal users.  Contains only content that has been explicitly
  promoted from `testing`.  Updated less frequently, after testing has validated the content.

> **Note:** The current CLI does not implement this V1 promotion flow. `./x remote promote`
> operates on V2 server snapshots (admitting `testing` checkouts into the `stable` channel
> under `efa/v2/`), not on V1 bundles and documents. The description below records the
> original V1 contract only.

Content was designed to flow from `testing` to `stable` via a promote command.  Promotion is
**selective** — individual bundles and documents are promoted, not the entire catalog.  ``testing``
remains the superset; ``stable`` is a curated subset.

Promotion copies channel-scoped JSON catalog entries to reference the same immutable objects
(document body files, bundle archives, bundle manifest snapshots).  No files are moved or duplicated.

### Common JSON Payload Rules

Every JSON payload in this contract must include `schemaVersion`:

```json
{
  "schemaVersion": 1
}
```

Common client rules:

- Reject unsupported `schemaVersion` values.
- Ignore absent optional sections.
- Treat remote fetch, parse, and validation failures as non-fatal.
- Preserve current local state when remote content cannot be loaded.
- Ignore unknown additive fields when `schemaVersion` is still supported.

### Channel Index

Path:

```text
efa/v1/channels/<channel>/index.json
```

Example:

```json
{
  "schemaVersion": 1,
  "generation": "20260605T120000Z",
  "generatedAt": "2026-06-05T12:00:00Z",
  "minClientApi": 1,
  "channel": "testing",
  "region": "global",
  "documents": {
    "catalogPath": "channels/testing/.generations/20260605T120000Z/documents/catalog.json",
    "revision": "docs-20260605T120000Z"
  },
  "app": {
    "releasesPath": "channels/testing/.generations/20260605T120000Z/app/releases.json",
    "revision": "app-20260605T120000Z"
  },
  "bundles": {
    "catalogPath": "channels/testing/.generations/20260605T120000Z/bundles/catalog.json",
    "revision": "bundles-20260605T120000Z"
  }
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `generation`: unique publish generation identifier (`YYYYMMDDThhmmssZ`).
  Every committed publish produces a new generation. Old generations are pruned
  by garbage collection (default keep count: 2).
- `generatedAt`: UTC timestamp for the index generation time.
- `minClientApi`: minimum client remote-content API version required to consume this index.
- `channel`: channel represented by this index. It must match the requested channel.
- `region`: optional storage or deployment region represented by this index.
- `documents`: optional document catalog section.
- `documents.catalogPath`: relative path to the channel document catalog.
  Located inside `.generations/{generation}/` to enable atomic publishes.
- `documents.revision`: opaque document catalog revision for diagnostics and cache decisions.
  Derived from the generation timestamp.
- `app`: optional app release metadata section.
- `app.releasesPath`: relative path to app release metadata.
- `app.revision`: opaque app release metadata revision.
- `bundles`: optional bundle catalog section.
- `bundles.catalogPath`: relative path to the channel bundle catalog.
  Located inside `.generations/{generation}/` for atomicity.
- `bundles.revision`: opaque bundle catalog revision.

### Documents Catalog

The catalog is located at the path specified by `documents.catalogPath` in the channel index.
In the generation-stamped layout:

```text
efa/v1/channels/<channel>/.generations/<generation>/documents/catalog.json
```

Legacy clients that hardcode `documents/catalog.json` are served by the backward-compatible
flat layout during the transition period (the tooling copies catalogs to legacy paths
automatically at publish time).

Example:

```json
{
  "schemaVersion": 1,
  "version": 1,
  "entries": [
    {
      "id": "maintenance-20260520T000000Z",
      "kind": "announcement",
      "source": "remote",
      "publishedAt": "2026-05-20T00:00:00Z",
      "tags": ["announcement", "maintenance"],
      "startup": true,
      "minAppVer": "0.0.1",
      "appVer": null,
      "localizations": {
        "en": {
          "title": "Maintenance notice",
          "summary": "A short remote announcement summary.",
          "bodyPath": "documents/body/en/maintenance-20260520T000000Z.md"
        },
        "zh": {
          "title": "维护公告",
          "summary": "一条简短的远程公告摘要。",
          "bodyPath": "documents/body/zh/maintenance-20260520T000000Z.md"
        }
      }
    },
    {
      "id": "version-0.0.2",
      "kind": "version",
      "source": "remote",
      "publishedAt": "2026-05-20T00:00:00Z",
      "tags": ["version"],
      "startup": false,
      "minAppVer": null,
      "appVer": "0.0.2",
      "localizations": {
        "en": {
          "title": "Version 0.0.2",
          "summary": "Release notes for version 0.0.2.",
          "bodyPath": "documents/body/en/version-0.0.2.md"
        },
        "zh": {
          "title": "版本 0.0.2",
          "summary": "版本 0.0.2 的发布说明。",
          "bodyPath": "documents/body/zh/version-0.0.2.md"
        }
      }
    }
  ]
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `version`: document catalog content version. This is distinct from `schemaVersion`.
- `entries`: document entries visible to the app.
- `id`: stable document id. Auto-generated: `version-{appVer}` for version entries,
  `{topic}-{timestamp}` for announcements (custom topic via `--id` prefix, timestamp always appended).
- `kind`: document kind. Supported values are `announcement`, `information`, and `version`.
- `source`: source marker. Remote catalogs must use `remote`.
- `publishedAt`: UTC publication timestamp.
- `tags`: optional tags for filtering or diagnostics.
- `startup`: whether an announcement is eligible for startup display.
- `minAppVer`: optional minimum app version for `announcement` and `information` entries.
- `appVer`: app version documented by a `version` entry.
- `localizations`: localized title, summary, and body location keyed by locale code.
- `title`: localized display title.
- `summary`: localized short summary and fallback body text.
- `bodyPath`: relative path to the remote Markdown body object.

Remote entries with the same `id` as bundled entries intentionally replace bundled entries in the
merged document feed. Use this only for intentional corrections.

### App Releases

The releases metadata is located at the path specified by `app.releasesPath` in the channel index.
In the generation-stamped layout:

```text
efa/v1/channels/<channel>/.generations/<generation>/app/releases.json
```

This file is auto-generated from version entries in the document catalog and the current
app version in `pubspec.yaml`.

Example:

```json
{
  "schemaVersion": 1,
  "releases": [
    {
      "platform": "android",
      "channel": "testing",
      "appVersion": "0.0.2",
      "buildNumber": 2,
      "publishedAt": "2026-05-20T00:00:00Z",
      "minimumSupportedVersion": "0.0.1",
      "releaseNoteDocumentId": "version-0.0.2",
      "downloadUrl": "https://example.com/eve-fit-assistant-0.0.2.apk",
      "sha256": "optional-apk-sha256",
      "generation": "20260605T120000Z"
    }
  ]
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `releases`: release metadata entries, auto-generated from version document entries
  in the document catalog.
- `platform`: target platform, such as `android`.
- `channel`: release channel.
- `appVersion`: user-facing app version.
- `buildNumber`: platform build number (parsed from `pubspec.yaml` `version: X.Y.Z+N`).
- `publishedAt`: UTC release publication timestamp.
- `minimumSupportedVersion`: optional minimum app version that remains supported.
- `releaseNoteDocumentId`: optional document id for release notes.
- `downloadUrl`: optional external download URL.
- `sha256`: optional SHA-256 for the externally downloaded app artifact.
- `generation`: publish generation that produced this release entry.

App release metadata is informational. It must not trigger in-app binary hot updates, runtime code
replacement, or dynamic Dart, native, or JavaScript loading.

### Bundle Catalog

The catalog is located at the path specified by `bundles.catalogPath` in the channel index.
In the generation-stamped layout:

```text
efa/v1/channels/<channel>/.generations/<generation>/bundles/catalog.json
```

Example:

```json
{
  "schemaVersion": 1,
  "artifacts": [
    {
      "artifactId": "data-tranquility-1234567",
      "bundleId": "tranquility",
      "variant": "full",
      "appVersion": "0.0.1+1",
      "gameVersion": "2026.05",
      "gameBuild": "1234567",
      "gameRegion": "global",
      "gameBranch": "release",
      "gameServer": "tranquility",
      "generatedAt": "2026-05-20T00:00:00Z",
      "artifactPath": "bundles/tranquility/data-tranquility-1234567.zip",
      "artifactSize": 123456789,
      "artifactSha256": "zip-sha256",
      "baseBundleId": null,
      "baseManifestHash": null
    }
  ]
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `artifacts`: available bundle artifacts.
- `artifactId`: stable, auto-generated artifact id in the form
  `data-{gameServer}-{gameBuild}`.
- `bundleId`: bundle identity installed by the app.
- `variant`: artifact variant. Supported value is `full` (legacy format).
- `appVersion`: app version that generated or supports the artifact.
- `gameVersion`: EVE game version represented by the bundle.
- `gameBuild`: EVE game build represented by the bundle.
- `gameRegion`: EVE game region represented by the bundle.
- `gameBranch`: EVE game branch represented by the bundle.
- `gameServer`: EVE game server represented by the bundle.
- `generatedAt`: UTC artifact generation timestamp.
- `artifactPath`: relative path to the bundle archive.
- `artifactSize`: bundle archive byte size.
- `artifactSha256`: bundle archive SHA-256 digest.
- `baseBundleId`: bundle id that must already be installed before applying a legacy incremental artifact.
- `baseManifestHash`: required installed manifest hash for legacy incremental artifacts.

This is a legacy bundle catalog format. New data distribution uses the V2 schema
with content-addressed checkout catalogs.

Client behavior used by EVE Fit Assistant:

- Full artifacts are eligible for explicit user-triggered import when the app version matches.
- Incremental artifacts are eligible only when an installed bundle registrar records the matching
  latest `manifestHash` for the artifact `baseManifestHash`.
- The client classifies artifacts as recommended, available, already installed, or unavailable.
- Already installed means the artifact manifest hash is present anywhere in the installed bundle
  registrar history, not just as the latest patch.
- Compatible incremental artifacts are recommended before full artifacts.
- Full artifacts remain available and can become the recommendation for new installs or when no
  matching incremental path exists for the installed manifest.
- After at least one bundle is installed, recommendations are limited to installed bundle ids. Full
  artifacts for other bundle ids remain available alternatives, not prompts to install every remote
  bundle.
- Recommendations for an installed bundle id must be newer than the newest installed artifact in the
  catalog. Older same-bundle full artifacts remain available alternatives and are not recommended
  after a newer incremental artifact is installed.
- Unavailable artifacts remain visible in the remote bundle review page with local reason text for
  app-version mismatch, missing incremental metadata, missing base bundle, missing installed manifest
  hash, or base manifest mismatch.
- The client verifies downloaded archive byte size and SHA-256 before import.
- Import uses the same local bundle import path and does not silently switch the active bundle.
- Endpoint `region` is storage/deployment metadata only; `gameRegion` remains artifact metadata and
  is not used as a client-side compatibility filter.

### Path Safety Rules (V1)

Relative paths advertised by v1 JSON payloads must resolve inside the configured `resourceRoot`.
This applies to channel catalog paths, document body paths, bundle artifact paths, and bundle
manifest paths.

`resourceRoot` rules:

- Must be relative.
- Must be non-empty.
- Must end with `/`.
- Must not start with `/`.
- Must not be an absolute URI.
- Must not contain `..` path segments.
- Must match the supported v1 resource root: `efa/v1/`.

Channel name rules:

- Must be one safe path segment.
- Must be non-empty.
- Must not contain `/`.
- Must not contain `..`.
- Must not use URI-encoded traversal.

Relative payload path rules:

- Must be relative.
- Must be non-empty.
- Must not start with `/`.
- Must not be an absolute URI.
- Must not contain `..` path segments after normalization.
- Must not use URI-encoded traversal such as `%2e%2e`.
- Must resolve under `<originUrl>/<resourceRoot>/`.

Accepted examples:

```text
channels/testing/documents/catalog.json
documents/body/en/remote-announcement-2026-05-maintenance.md
bundles/tranquility/tranquility-full-20260520.zip
```

Rejected examples:

```text
https://evil.example.com/catalog.json
/channels/testing/documents/catalog.json
../catalog.json
documents/../../secret.md
%2e%2e/secret.md
```

### S3-Compatible Publishing Rules (V1)

The layout is designed to work as public read-only static object storage. The app never receives
S3, R2, OSS, or RustFS credentials.

Each publish produces a **generation** — a self-contained snapshot written to a timestamped
directory under `.generations/`. The channel `index.json` is the sole live-mutated object;
its S3 PUT is atomic, making the entire publish an atomic commit.

Recommended publishing order:

1. Upload shared immutable resources first (same paths as v1):

   ```text
   efa/v1/documents/body/**
   efa/v1/bundles/**
   ```

2. Upload generation-specific catalog metadata next (NEW paths, never overwrites live state):

   ```text
   efa/v1/channels/<channel>/.generations/<generation>/documents/catalog.json
   efa/v1/channels/<channel>/.generations/<generation>/app/releases.json
   efa/v1/channels/<channel>/.generations/<generation>/bundles/catalog.json
   ```

3. Upload the generation's index to the channel index last (atomic S3 PUT):

   ```text
   efa/v1/channels/<channel>/.generations/<generation>/index.json
       → efa/v1/channels/<channel>/index.json
   ```

This three-step order ensures that interruption at any point leaves the live state consistent:
before the index update clients see the previous generation; after the index update
they see the fully-uploaded new generation.

The current CLI has no helper that uploads this V1 layout: `./x remote publish` publishes
V2 session-staged content under `efa/v2/` only, and V1 objects can no longer be published
to the local mock. Document-style remote catalogs are managed with `./x remote announce`
under `efa/v2/`.

#### Garbage Collection (V1)

The current CLI does not provide V1 garbage collection: `./x remote publish gc` is not a
registered command (`./x remote publish` takes no subcommands), and `./x remote gc`
operates on local V2 storage only. Under the original contract, old generations were
pruned automatically when `--clean` was passed to `publish upload`, or via a separate
`gc` run; `--keep-generations` defaulted to 2 (current + 1 previous) to allow rollback to
the previous generation by re-copying its `index.json` over the live path.

#### Rollback (V1)

To revert a bad publish, copy the previous generation's index to the live path with any
S3-compatible client:

```bash
aws s3 cp s3://<bucket>/efa/v1/channels/<channel>/.generations/<prev_gen>/index.json \
          s3://<bucket>/efa/v1/channels/<channel>/index.json --endpoint-url <endpoint>
```

Recommended cache policy:

```text
efa/v1/channels/<channel>/index.json
  Cache-Control: no-cache or max-age=30

efa/v1/channels/<channel>/.generations/<gen>/**/*.json
  Cache-Control: max-age=60..300

efa/v1/documents/**
efa/v1/bundles/**
  Cache-Control: immutable, max-age=31536000
```

### Local Mock Layout (V1)

Local mocks should use the same object layout as production storage. The committed fixture
source documenting the v1 object layout lives under:

```text
docs/examples/remote/mock-origin/
```

The current mock tooling neither copies nor serves that tree: `./x remote mock launch`
starts a RustFS server backed by the persisted store (run `./x remote mock clean` first if
you need an empty one), and `./x remote publish` uploads session-staged content under
`efa/v2/` only. V1 objects can no longer be published to the local mock.

RustFS bucket endpoint:

```bash
./x remote mock launch
```

Channel registry and head URLs after publishing:

```text
http://127.0.0.1:9000/efa-dev/efa/v2/channels/heads/channels.json
http://127.0.0.1:9000/efa-dev/efa/v2/channels/heads/testing/metadata.json
```

The RustFS object store persists under the configured developer data directory. With the default
configuration this is `cache/remote/mock-data/`. Change `[paths].root` or
`[remote.mock].data_dir` in `efa.dev.toml` to move that persistent store.

## Schema V2 Storage

Schema V2 replaces the bundle-based data delivery model with **content-addressed checkouts**
and **generation-based atomic publishing**. The remote layout is `efa/v2/`: per-channel
mutable state lives under `channels/heads/` (channel registry plus per-channel head
metadata), immutable published generations live under `channels/refs/{generation_hash}/`,
and content-addressed payloads live under `assets/` — separate from v1's `efa/v1/`.

`v2` is a different resource root from v1. Breaking changes to object layout, JSON semantics,
or required fields use a new resource root. Existing v1 clients continue to read `efa/v1/`
objects and are not redirected without an explicit client update.

The v2 storage contract covers:

- Content-addressed asset storage and checkout (data snapshot) catalogs.
- Generation-based atomic publishing under `channels/` (mutable heads, immutable refs).
- App release metadata with per-platform content-addressed APKs.

### V2 Data Generation

`./x build data` produces a v2 resource snapshot in the schema root (default
`cache/schema/`):

- `assets/blobs/{2c}/{ident_hash}/{content_hash}` — content-addressed file store.
- `assets/resources/<snapshot_hash>/` — immutable snapshot with `metadata.json` (server
  metadata) and `resources.pb2` (resource index: resource ID, content hash, and size per
  entry).

The snapshot hash is the v4 structured hash over `metadata.json` and `resources.pb2`
(see `bootstrap/remote/hash.py`). `metadata.json` carries the build-time `createdAt`
timestamp, so builds with identical game data can produce different snapshot hashes when
they run at different times — snapshot identity is not a pure function of game data alone.
`createdAt` has one-second precision, so builds at different times within the same second
share a timestamp and can therefore share the same hash.

Blob deduplication is separate from snapshot identity. A blob path
`assets/blobs/{2c}/{ident_hash}/{content_hash}` depends on both the resource ID and the
content hash. Identical file contents therefore share one entry across snapshots and
generations only for the same resource ID; identical files with different resource IDs do
not share the same entry, regardless of snapshot hash.

Standalone generation:

```bash
./x generate schema --dir <build_dir> --server <server_id>
```

Schema output lands at the schema root (`--schema-root`, default `cache/schema/`).

### V2 Canonical Object Layout

The published tree follows the canonical v2 layout. Mutable channel state lives
under `channels/heads/`, immutable published generations live under
`channels/refs/{generation_hash}/`, and content-addressed payloads live under
`assets/`:

```text
efa/v2/
  channels/
    heads/
      channels.json                     # Channel registry (defaultChannel + labels).
      {channel}/
        metadata.json                   # Channel head metadata (mutable generation pointer).
        reflog.pb2                      # Append-only head movement log.
        suppressions.json               # Promotion suppression list.
    refs/
      {generation_hash}/
        metadata.json                   # Generation metadata (parent, channel, timestamp).
        server.pb2                      # Server index.
        resources.pb2                   # Generation resources (server -> snapshot hash).
        releases.pb2                    # Release pointer (release snapshot hash).
        history.pb2                     # Per-server snapshot history.
  assets/
    blobs/{2c}/{ident_hash}/{content_hash}  # Content-addressed file store.
    resources/{snapshot_hash}/        # Resource snapshot.
      metadata.json                     # Server metadata.
      resources.pb2                     # Resource index (resource ID, content hash, size).
    releases/{snapshot_hash}/         # Release snapshot.
      metadata.json                     # Release metadata.
      releases.pb2                      # Release index (version, offering, artifacts).
```

### Channel Registry

Located at `channels/heads/channels.json`. Lists every published channel, its localized
labels, and the default channel:

```json
{
  "schemaVersion": 1,
  "defaultChannel": "stable",
  "channels": {
    "stable": { "label": { "en": "Stable", "zh": "稳定版" } },
    "testing": { "label": { "en": "Testing", "zh": "测试版" } }
  }
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `defaultChannel`: channel new clients follow when none is configured. The remote key is
  `defaultChannel`; the client model stores it as `active` and maps the key on parse.
- `channels`: registered channels keyed by channel name; each entry carries a localized
  `label` map.

### Channel Head Metadata

Located at `channels/heads/{channel}/metadata.json`. The sole mutable pointer in the
tree — changing it is an atomic publish:

```json
{
  "schemaVersion": 1,
  "generationHash": "<generation hash>",
  "updatedAt": "2026-06-13T00:00:00Z",
  "label": { "en": "Stable", "zh": "稳定版" }
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `generationHash`: hash of the active generation. Changing this atomically commits a new
  publish. The previous generation remains intact under `channels/refs/<prev_hash>/`.
- `updatedAt`: UTC timestamp of the last head movement (ISO 8601).
- `label`: localized channel display labels.

### Head Reflog

Located at `channels/heads/{channel}/reflog.pb2` (protobuf `HeadReflog`). Append-only log
of every channel head pointer movement:

```
schema_version: 1
entries {
  from: "<previous generation hash>"   # empty for the initial push
  to: "<new generation hash>"
  op: "push"                           # "push" | "revert"
  timestamp: "2026-06-13T00:00:00Z"    # ISO 8601
}
```

### Generation Metadata

Each generation has a `metadata.json` in `channels/refs/{generation_hash}/`:

```json
{
  "schemaVersion": 1,
  "parent": "<parent generation hash>",
  "channel": "stable",
  "timestamp": "2026-06-13T00:00:00Z",
  "subject": "publish / promote subject line"
}
```

The `parent` chain plus the head `reflog.pb2` replace the old append-only generations
index: generation history is recovered by walking `parent` links, and head movement is
audited through the reflog.

### Server Index and Generation Resources

**Server index** (`channels/refs/{generation_hash}/server.pb2`, protobuf `ServerIndex`) —
complete server catalog at the time of the generation:

```
schema_version: 1
servers {
  server_id: "<server_id>"
  name: { "en": "Server Name", "zh": "服务器名称" }
  game_build: "<game build>"
  game_version: "<game version>"
  region: "<game region>"        # optional
  sync: "<game sync>"            # optional
  branch: "<game branch>"        # optional
}
```

**Generation resources** (`channels/refs/{generation_hash}/resources.pb2`, protobuf
`GenerationResources`) — maps every server to its current resource snapshot hash:

```
schema_version: 1
entries {
  server_id: "<server_id>"
  snapshot_hash: "<resource snapshot hash>"
}
```

**Resource snapshot metadata** (`assets/resources/{snapshot_hash}/metadata.json`) — server
metadata for one snapshot:

```json
{
  "schemaVersion": 1,
  "serverId": "<server_id>",
  "gameBuild": "<game build>",
  "gameVersion": "<game version>",
  "resourceCount": 0,
  "createdAt": "2026-06-13T00:00:00Z",
  "name": { "en": "Server Name", "zh": "服务器名称" },
  "gameRegion": "<game region>",
  "gameSync": "<game sync>",
  "gameBranch": "<game branch>"
}
```

**Resource index** (`assets/resources/{snapshot_hash}/resources.pb2`, protobuf
`ResourceIndex`) — authoritative file-to-content mapping for the snapshot:

Current model-bearing snapshots stamp `format_version: 3` (format-2 clients reject
them; format 1 is a legacy/minimal index with no `download_policy` fields):

```
schema_version: 1
format_version: 3
entries {
  resource_id: "resource://static/native/types.pb2"
  content_hash: "<content hash>"
  size: 0
  download_policy: FORCE      # eager download (policy fields require format_version >= 2)
}
entries {
  resource_id: "resource://static/models/ships/<ship>.glb"
  content_hash: "<content hash>"
  size: 0
  download_policy: NON_FORCE  # lazy on first access; format 3 admits lazy static/models/ entries
}
```

All blobs live in the shared `assets/blobs/{2c}/{ident_hash}/{content_hash}` store,
addressed by SHA-256 of the `resource_id` and the content bytes.

The client recomputes the snapshot hash from the downloaded index, but does not compare it
with the advertised hash to verify integrity: the recomputed value becomes the snapshot's
new local identity. It is the v4 structured hash binding the canonical `metadata.json` and
the `resources.pb2` index:

```
snapshotHash = SHA-256(
    "efa:resource:v4\n" +
    "metadata.json <sha256 of canonical metadata.json bytes>\n" +
    "resources.pb2 <sha256 of resources.pb2 bytes>\n"
)
```

### Release Pointer and Release Index

**Release pointer** (`channels/refs/{generation_hash}/releases.pb2`, protobuf
`GenerationPointer`) — points to the release snapshot active for the generation:

```
schema_version: 1
snapshot_hash: "<release snapshot hash>"
```

**Release snapshot metadata** (`assets/releases/{snapshot_hash}/metadata.json`) — release
snapshot metadata:

```json
{
  "schemaVersion": 1,
  "releaseCount": 1,
  "createdAt": "2026-06-13T00:00:00Z",
  "versionMin": "<minimum app version>",
  "versionMax": "<maximum app version>",
  "author": "<author>",
  "description": "<description>"
}
```

**Release index** (`assets/releases/{snapshot_hash}/releases.pb2`, protobuf `ReleaseIndex`) —
describes a single release with per-platform artifact metadata:

```
schema_version: 1
id: "<release id>"
version: "0.2.0"
build: 0                    # optional; monotonic build number (Android versionCode)
android {
  general { identifier: "...", content_hash: "...", size: 0 }
  arm64 { identifier: "...", content_hash: "...", size: 0 }   # optional
  x64 { identifier: "...", content_hash: "...", size: 0 }     # optional
}
```

Artifact `content_hash` values resolve to the shared content-addressed blob store at
`assets/blobs/{2c}/{ident_hash}/{content_hash}`. The release snapshot hash is the v4
structured hash over `metadata.json` and `releases.pb2` (`efa:release:v4`).

### V2 Remote Publishing Session

The `./x remote session` sub-group stages resource and release snapshots and assembles
generations under the schema root, and `./x remote publish` uploads the committed head to
`channels/heads/` and the immutable generation to `channels/refs/`:

```bash
# Start a session
./x remote session init stable

# Stage server data (resource snapshot hash from the build)
./x remote session add --resource --hash <snapshot_hash>

# Stage an APK release (release registry JSON with per-platform APK entries)
./x remote session add --release --file <release_registry.json>

# Assemble the generation and advance the channel head
./x remote session commit

# Publish to S3/R2 (uploads the head generation, changed snapshots, blobs)
./x remote publish stable --target s3
```

Config is read from `efa.config.toml` `[data_schema]` section (`resource_root`,
`channel`, `schema_version`). Developer remote settings come from
`efa.dev.toml`: S3-compatible publishing credentials from `[remote.s3]`, the
local RustFS mock from `[remote.mock]`, with shared defaults under `[remote]`.

### V2 Publishing Rules

Each publish produces a **generation** — a self-contained snapshot written to
`channels/refs/{generation_hash}/`. The `channels/heads/{channel}/metadata.json` S3 PUT
is atomic, making the entire publish an atomic commit.

Recommended publishing order:

1. Upload shared immutable assets first:
   ```text
   efa/v2/assets/blobs/**
   efa/v2/assets/resources/<snapshot_hash>/**
   efa/v2/assets/releases/<snapshot_hash>/**
   ```

2. Upload the immutable generation:
   ```text
   efa/v2/channels/refs/{generation_hash}/**
   ```

3. Update the channel head (atomic S3 PUT to activate the generation):
   ```text
   efa/v2/channels/heads/{channel}/metadata.json
   efa/v2/channels/heads/{channel}/reflog.pb2
   ```

4. Update the channel registry when channels or the default channel change:
   ```text
   efa/v2/channels/heads/channels.json
   ```

This order ensures that interruption at any point leaves the live state consistent:
before the head update clients see the previous generation; after the head update
they see the fully-uploaded new generation.

### V2 Garbage Collection

Old generations are pruned by `./x remote gc [--dry-run] [--retention-depth <N>]`,
keeping a configurable number of recent generations. `--retention-depth` counts
ancestor (non-head) generations; the default is `0`, which keeps **only the
current head** and prunes every ancestor. Note that with the default, the
previous generation is deleted, so V2 Rollback (below) to it is no
longer possible. Run with `--retention-depth 1` to keep the current head plus
the previous generation, preserving the rollback target.

> **Warning:** `./x remote gc` currently keeps retained release snapshot
> directories but does not mark their release artifact blobs (APK, AppImage,
> installer, etc.) as reachable, so it deletes those blobs from `assets/blobs/`
> even with `--retention-depth 1`. If the blobs were never uploaded, the next
> `./x remote publish` fails with `Release blob missing` because the retained
> release snapshot still references them. Until GC preserves release blobs,
> publish release artifacts before running GC, or back up `assets/blobs/`; to
> recover, rebuild or restore the artifacts and republish. Use `--dry-run` to
> inspect deletions without applying them.

### V2 Rollback

Move the generation pointer in `channels/heads/{channel}/metadata.json` back to a
previous generation hash (via `./x remote revert`, which also appends a `revert` entry
to `reflog.pb2`).

`revert` changes the local schema root only; the remote head still points at the newer
generation. Publish the reverted head to move the remote pointer back as well:

```bash
./x remote revert <channel> <generation_hash>
./x remote publish <channel> --target <target>
```

### V2 Client Discovery

Clients start from the configured origin:

```text
<originUrl>/efa/v2/channels/heads/channels.json
<originUrl>/efa/v2/channels/heads/{channel}/metadata.json
```

From the registry and head metadata they resolve:
1. The active channel → `generationHash` → generation content under
   `channels/refs/{generationHash}/` (`server.pb2`, `resources.pb2`, `releases.pb2`).
2. Server entries → per-server snapshot hash → `assets/resources/{snapshot_hash}/`
   (`metadata.json`, `resources.pb2`) → blob paths under `assets/blobs/`.
3. Release pointer → release snapshot → `assets/releases/{snapshot_hash}/` → APK blob.

### V2 Local Mock Layout

Local mocks for v2 use the canonical v2 layout described in
[V2 Canonical Object Layout](#v2-canonical-object-layout): `channels/heads/` for
mutable channel state (including `channels.json`), `channels/refs/{generation_hash}/`
for immutable generations, and `assets/` for content-addressed payloads and
snapshots.

The committed fixture under `docs/examples/remote/mock-origin/` still uses the V1
layout and has no `channels/heads/channels.json`, so it is not a valid v2 origin
layout reference.

The `./x remote session` CLI manages v2 staging. For local development with the
RustFS mock, configure `[remote.mock]` in `efa.dev.toml`:

```bash
./x remote session init testing
./x remote session add --resource --hash <snapshot_hash>
./x remote session add --release --file <release_registry.json>
./x remote session commit
./x remote publish testing --target mock
```

### V2 Path Safety Rules

Path safety rules from v1 apply with equal strictness to v2:

- All relative paths must resolve under `efa/v2/`.
- No `..` segments or URI-encoded traversal.
- `channels/heads/` (the channel registry and per-channel head metadata) is the
  mutable surface; `channels/refs/<gen>/` content is immutable after publish.

### V2 S3-Compatible Publishing

The `./x remote publish` command follows the same atomic
publish pattern as v1:

```bash
./x remote publish <channel> --target s3
```

Config defaults read from `efa.dev.toml` `[remote]` section (endpoint, bucket,
credentials, alias). Production credentials are managed by release tooling
and must not be shipped in the app.

### App-Side V2 Sync

The Flutter client resolves data through the V2 repository system:

- `RemoteCatalogService` fetches the channel registry at
  `channels/heads/channels.json`, resolves each channel head via
  `channels/heads/{channel}/metadata.json`, and reads the immutable generation
  content under `channels/refs/{generationHash}/` (server, resources, releases,
  and history indexes).
- `ReleaseSyncService` compares the installed app version against the
  release catalog and reports whether a newer release is available
  (detection only; it does not download or install artifacts).
- The `RepoCollectionService` loads type data (ships, skills, items,
  localization, icons) from the active checkout's content-addressed asset store.
- Fits and characters store a `CheckoutRef` binding (checkout hash + server
  metadata) for compatibility verification on load.

## Compatibility And Evolution

Additive fields may be introduced while keeping `schemaVersion: 1` when old clients
can safely ignore them. Breaking changes require a new resource root:

```text
efa/v2/   (current schema v2)
efa/v3/   (future, for v3-breaking changes)
```

Existing v1 clients continue to read `efa/v1/` objects and should not be
redirected to a newer resource root without an explicit client update.
