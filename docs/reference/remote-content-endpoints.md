# Remote Content V1 Storage Contract

This reference defines the version 1 remote content storage contract for EVE Fit
Assistant. The contract is designed for static HTTP and S3-compatible object storage,
including Cloudflare R2, Alibaba OSS, MinIO, and CDN-backed buckets.

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

## Versioned Storage Model

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

## Endpoint Configuration Semantics

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
  mock origin. It may include a bucket path, such as a MinIO bucket prefix.
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

## Canonical Object Layout

The canonical object layout follows the V2 schema specification (`efa/v2/`).

## Channel Semantics

Channels are content streams, not API versions. Two channels are defined:

```text
testing
stable
```

- **testing** — bleeding-edge data for developers and early testers. May contain incomplete content,
  internal-only announcements, and experimental bundles.  Updated frequently.
- **stable** — validated data for normal users.  Contains only content that has been explicitly
  promoted from `testing`.  Updated less frequently, after testing has validated the content.

Content flows from `testing` to `stable` via the ``./x remote promote`` command.  Promotion is
**selective** — individual bundles and documents are promoted, not the entire catalog.  ``testing``
remains the superset; ``stable`` is a curated subset.

Promotion copies channel-scoped JSON catalog entries to reference the same immutable objects
(document body files, bundle archives, bundle manifest snapshots).  No files are moved or duplicated.

## Common JSON Payload Rules

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

## Channel Index

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

## Documents Catalog

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

## App Releases

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

## Bundle Catalog

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

## Path Safety Rules

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

## S3-Compatible Publishing Rules

The layout is designed to work as public read-only static object storage. The app never receives
S3, R2, OSS, or MinIO credentials.

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

The repository helper follows this order when uploading a local origin to MinIO or another
S3-compatible endpoint:

```bash
./x remote publish upload --target minio
```

### Garbage Collection

Old generations are pruned automatically when `--clean` is passed to `publish upload`,
or can be run separately:

```bash
./x remote publish gc [--dry-run] [--keep-generations <N>]
```

`--keep-generations` defaults to 2 (current + 1 previous) to allow rollback to the
previous generation by re-copying its `index.json` over the live path.

### Rollback

To revert a bad publish, copy the previous generation's index to the live path:

```bash
mc cp <alias>/<bucket>/efa/v1/channels/<channel>/.generations/<prev_gen>/index.json \
      <alias>/<bucket>/efa/v1/channels/<channel>/index.json
```

Recommended cache policy:

```text
efa/v2/channels/<channel>/index.json
  Cache-Control: no-cache or max-age=30

efa/v2/channels/<channel>/.generations/<gen>/**/*.json
  Cache-Control: max-age=60..300

efa/v2/announcements/**
  Cache-Control: immutable, max-age=31536000 when ids are revisioned

efa/v2/resources/**
  Cache-Control: immutable, max-age=31536000
```

## Local Mock Layout

Local static mocks should use the same object layout as production storage. The committed fixture
source lives under:

```text
docs/examples/remote/mock-origin/
```

`./x remote mock materialize` copies that fixture tree into the developer mock origin directory.
With the default `efa.dev.toml` values, the runtime layout is:

```text
cache/remote/mock-origin/efa/v1/channels/testing/index.json
cache/remote/mock-origin/efa/v1/channels/testing/.generations/<gen>/documents/catalog.json
cache/remote/mock-origin/efa/v1/channels/testing/.generations/<gen>/app/releases.json
cache/remote/mock-origin/efa/v1/channels/testing/.generations/<gen>/bundles/catalog.json
cache/remote/mock-origin/efa/v1/documents/body/en/remote-announcement-2026-05-maintenance.md
```

The mock origin fixtures at `docs/examples/remote/mock-origin/` use the legacy flat layout
(without `.generations/`). At publish time, the tooling wraps legacy sources into a
generation directory automatically, so existing mock fixtures remain compatible.

Static HTTP mock endpoint:

```bash
./x remote mock launch --backend static
```

Channel index URL:

```text
http://127.0.0.1:8765/efa/v1/channels/testing/index.json
```

MinIO-style bucket endpoint:

```bash
./x remote mock launch --backend minio
```

Channel index URL:

```text
http://127.0.0.1:9000/efa-dev/efa/v1/channels/testing/index.json
```

The MinIO object store persists under the configured developer data directory. With the default
configuration this is `cache/remote/minio-data/`. Change `[paths].root` or
`[remote].minio_data_dir` in `efa.dev.toml` to move that persistent store.

## V2 Storage Contract

Schema V2 introduces a fundamentally different remote storage model: **content-addressed checkouts**
and **generation-based atomic publishing** at `efa/v2/<channel>/`. This section documents the v2
contract.

The v2 storage contract covers:

- Content-addressed asset storage and checkout (data snapshot) catalogs.
- Generation-based atomic publishing under `manifest/`.
- App release metadata with per-platform content-addressed APKs.
- Announcement catalogs with XOR-hashed content verification.

### Resource Root

```text
efa/v2/
```

`v2` is a different resource root from v1. Breaking changes to object layout, JSON semantics,
or required fields use a new resource root. Existing v1 clients continue to read `efa/v1/`
objects and are not redirected without an explicit client update.

### Canonical Object Layout

```text
efa/v2/<channel>/
  manifest/
    index.json                          # Activated generation pointer.
    generations.json                    # Append-only generation index.
    .generations/<gen_id>/
      catalog.json                      # Generation catalog (id, createdAt, description).
      resources/
        catalog.json                    # Server ID listing.
        servers/<server_id>.json        # Server catalog.
        checkouts/<checkout_hash>.json  # Checkout catalog (full file manifest).
      releases/
        catalog.json                    # Release catalog (version, offering, downloadHash).
      announcements/
        catalog.json                    # Announcement catalog (hash, versions, isVersionUpdate).
    checkouts/
      <2c>/<hash>.json                  # Flat content-addressed checkout registry.
  resources/
    releases/
      <2c>/<hash>                       # Content-addressed APK binaries.
    assets/
      <2c pathHash>/<pathHash>/<contentHash>  # Content-addressed data files.
  announcements/
    files/<locale>/<id>                 # Markdown announcement bodies.
    registry/<id>.json                  # Full announcement records (title, excerpt, tags).
```

### Manifest Index

Located at `manifest/index.json`. The sole mutable pointer in the tree — changing it is an
atomic publish:

```json
{
  "manifestVersion": 1,
  "activatedGeneration": "<generation uuid>"
}
```

Field semantics:

- `manifestVersion`: JSON schema version for this payload.
- `activatedGeneration`: ID of the active generation. Changing this atomically commits
  a new publish. The previous generation remains intact under `.generations/<prev_gen>/`.

### Generations Index

Located at `manifest/generations.json`. Append-only history of all published generations:

```json
{
  "generations": {
    "<gen_id>": {
      "id": "<gen_id>",
      "createdAt": "2026-06-13T00:00:00Z",
      "description": "Generation description."
    }
  }
}
```

### Generation Catalog

Each generation has a `catalog.json` in `.generations/<gen_id>/`:

```json
{
  "catalogVersion": 1,
  "createdAt": "2026-06-13T00:00:00Z",
  "description": "Catalog description."
}
```

### Server Catalog and Resources

**Resources catalog** (`resources/catalog.json`) — server listing:

```json
{
  "resourcesVersion": 1,
  "servers": {
    "<server_id>": "<server_id>"
  }
}
```

**Server catalog** (`resources/servers/<server_id>.json`) — server metadata and checkout list:

```json
{
  "id": "<server_id>",
  "lastUpdatedAt": "2026-06-13T00:00:00Z",
  "name": { "en": "Server Name", "zh": "服务器名称" },
  "metadata": {
    "gameServer": "<game server>",
    "gameBuild": "<game build>",
    "gameVersion": "<game version>"
  },
  "checkouts": [
    {
      "id": "<checkout hash>",
      "createdAt": "2026-06-13T00:00:00Z",
      "metadata": { "gameServer": "...", "gameBuild": "...", "gameVersion": "..." }
    }
  ]
}
```

**Checkout catalog** (`resources/checkouts/<checkout_hash>.json` and
`manifest/checkouts/<2c>/<hash>.json`) — full file manifest:

```json
{
  "id": "<checkout hash>",
  "createdAt": "2026-06-13T00:00:00Z",
  "serverId": "<server_id>",
  "metadata": { "gameServer": "...", "gameBuild": "...", "gameVersion": "..." },
  "files": {
    "<relative file path>": {
      "pathHash": "<filepath hash>",
      "hash": "<content hash>",
      "size": 0
    }
  }
}
```

The checkout hash is recomputed by the client to verify integrity:

```
checkoutId = SHA-256(
    "efa:checkout:v2\n" +
    "count:" + str(len(files)) + "\n" +
    for path in sorted(files.keys):
        "\t" + path + "\t" + content_hash + "\n"
)
```

The flat checkout registry at `manifest/checkouts/<2c>/<hash>.json` mirrors
the generation-scoped catalog so clients can resolve arbitrary checkout hashes
without knowing the generation.

### Release Catalog

Located at `.generations/<gen_id>/releases/catalog.json`:

```json
{
  "releasesVersion": 1,
  "releases": {
    "<release id>": {
      "id": "<release id>",
      "createdAt": "2026-06-13T00:00:00Z",
      "version": "<semantic version>",
      "offering": ["apk"],
      "downloadHash": "<apk content hash>"
    }
  }
}
```

Field semantics:

- `releasesVersion`: JSON schema version for this payload.
- `releases`: map of release entries keyed by release ID.
- `id`: stable release identifier.
- `createdAt`: UTC release timestamp (ISO 8601, second precision).
- `version`: semantic version string visible to the user.
- `offering`: available artifact types (currently `["apk"]`).
- `downloadHash`: content hash resolving to `resources/releases/<2c>/<hash>`.

### Release Item Record

Individual release records stored content-addressed at
`resources/releases/<2c>/<downloadHash>`:

```json
{
  "id": "<release id>",
  "createdAt": "2026-06-13T00:00:00Z",
  "version": "0.2.0",
  "versionUpdateAnnouncement": "<announcement id>",
  "files": {
    "apk": {
      "arm64": "<content hash>",
      "x86_64": "<content hash>",
      "combined": "<content hash>"
    }
  }
}
```

The `files` field is a nested map: offering name → (platform/ABI key → content hash).
Platform keys include `arm64`, `x86_64`, `arm32`, and `combined` (universal APK).

### Announcement Catalog

Located at `.generations/<gen_id>/announcements/catalog.json`:

```json
{
  "announcementsVersion": 1,
  "announcements": {
    "<announcement id>": {
      "id": "<announcement id>",
      "firstPublishedAt": "2026-06-13T00:00:00Z",
      "updatedAt": "2026-06-13T00:00:00Z",
      "versionRange": { "min": "0.1.0", "max": "0.2.0" },
      "contentHash": "<XOR composite hash of all locale bodies>",
      "isVersionUpdate": false
    }
  }
}
```

The catalog contains only the fields needed for update detection. Full localized
title, excerpt, and tags are stored in individual announcement record files at
`announcements/registry/<id>.json`. Markdown bodies live at
`announcements/files/<locale>/<id>`.

The `contentHash` is an XOR composite of all locale body hashes (see the
[schema specification](../../../../agent/schemav2/spec.md) § Content Hash).

### Publishing Rules

Each publish produces a **generation** — a self-contained snapshot written to
`manifest/.generations/<gen_id>/`. The `manifest/index.json` S3 PUT is atomic,
making the entire publish an atomic commit.

Recommended publishing order:

1. Upload shared immutable resources first:
   ```text
   efa/v2/<channel>/resources/releases/**
   efa/v2/<channel>/resources/assets/**
   efa/v2/<channel>/announcements/**
   efa/v2/<channel>/manifest/checkouts/**
   ```

2. Upload generation-specific catalog metadata:
   ```text
   efa/v2/<channel>/manifest/.generations/<gen_id>/**
   ```

3. Update `manifest/index.json` (atomic S3 PUT to activate the generation):
   ```text
   efa/v2/<channel>/manifest/index.json
   ```

4. Append to `manifest/generations.json`:
   ```text
   efa/v2/<channel>/manifest/generations.json
   ```

This order ensures that interruption at any point leaves the live state consistent:
before the index update clients see the previous generation; after the index update
they see the fully-uploaded new generation.

### Garbage Collection

Old generations are pruned automatically, keeping a configurable number of
recent generations (default: 2 — current + 1 previous for rollback).

### Rollback

Move the generation pointer in `manifest/index.json` to a previous generation ID.

### Client Discovery

Clients start from the configured origin + channel:

```text
<originUrl>/efa/v2/<channel>/manifest/index.json
```

From the index they resolve:
1. The active generation → generation catalog → resources catalog.
2. Server catalogs → checkout catalog → file manifest → asset paths.
3. Release catalog → download hash → APK binary.
4. Announcement catalog → content hash comparison → registry + body files.

### Local Mock Layout

Local static mocks for v2 use the same object layout. Committed fixture source:

```text
docs/examples/remote/mock-origin/efa/v2/
```

The `./x remote prepare` CLI manages v2 publishing. For local development with
MinIO, configure `[remote]` in `efa.dev.toml`:

```bash
./x remote prepare prepare --backend minio --channel testing --description "Local test"
./x remote prepare add-resources --checkout <path> --server <id> --name-en "..." --name-zh "..."
./x remote prepare add-release --version "0.2.0" --apk <path>
./x remote prepare publish
```

### Path Safety Rules

Path safety rules from v1 apply with equal strictness to v2:

- All relative paths must resolve under `efa/v2/`.
- No `..` segments or URI-encoded traversal.
- `manifest/index.json` and `manifest/generations.json` under each channel
  are the mutable surface; `.generations/<gen>/` content is immutable after publish.

### S3-Compatible Publishing

The `./x remote prepare publish` command follows the same `mc`-based atomic
publish pattern as v1:

```bash
./x remote prepare publish
```

Config defaults read from `efa.dev.toml` `[remote]` section (endpoint, bucket,
credentials, alias). Production credentials are managed by release tooling
and must not be shipped in the app.


## Compatibility And Evolution

Additive fields may be introduced while keeping `schemaVersion: 1` (v1) or
`manifestVersion: 1` / `releasesVersion: 1` (v2) when old clients can safely
ignore them. Breaking changes require a new resource root:

```text
efa/v2/   (current schema v2)
efa/v3/   (future, for v3-breaking changes)
```

Existing v1 clients continue to read `efa/v1/` objects and should not be
redirected to a newer resource root without an explicit client update.
