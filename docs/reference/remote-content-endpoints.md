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

`v1` is the storage and wire-schema version. It is separate from content channels such as `alpha`
or `stable`. Breaking changes to object layout, JSON semantics, or required fields must use a new
resource root such as `efa/v2/`.

## Endpoint Configuration Semantics

Clients conceptually need these fields to locate remote content:

```json
{
  "enabled": false,
  "originUrl": "https://updates.example.com/",
  "resourceRoot": "efa/v1/",
  "channel": "alpha",
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
https://updates.example.com/efa/v1/channels/alpha/index.json
```

## Canonical Object Layout

The canonical v1 object layout is:

```text
efa/v1/channels/<channel>/index.json
efa/v1/channels/<channel>/documents/catalog.json
efa/v1/channels/<channel>/app/releases.json
efa/v1/channels/<channel>/bundles/catalog.json
efa/v1/documents/body/<locale>/<document-id>.md
efa/v1/bundles/<bundle-id>/<artifact-id>.zip
efa/v1/bundles/<bundle-id>/<artifact-id>.manifest.json
```

Channel-scoped JSON files are mutable metadata. Document body objects and bundle objects should be
treated as immutable when their object names include revisioned document ids or artifact ids.

## Channel Semantics

Channels are content streams, not API versions. Recommended channel names are:

```text
dev
alpha
beta
stable
```

Recommended promotion flow:

```text
dev -> alpha -> beta -> stable
```

Promotion should copy or rewrite small channel-scoped JSON catalogs. Promotion should not move or
rename immutable document body objects, bundle archives, or bundle manifest snapshots.

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
  "generatedAt": "2026-05-20T00:00:00Z",
  "minClientApi": 1,
  "channel": "alpha",
  "region": "global",
  "documents": {
    "catalogPath": "channels/alpha/documents/catalog.json",
    "revision": "docs-20260520"
  },
  "app": {
    "releasesPath": "channels/alpha/app/releases.json",
    "revision": "app-0.0.2"
  },
  "bundles": {
    "catalogPath": "channels/alpha/bundles/catalog.json",
    "revision": "tq-20260520"
  }
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `generatedAt`: UTC timestamp for the index generation time.
- `minClientApi`: minimum client remote-content API version required to consume this index.
- `channel`: channel represented by this index. It must match the requested channel.
- `region`: optional storage or deployment region represented by this index.
- `documents`: optional document catalog section.
- `documents.catalogPath`: relative path to the channel document catalog.
- `documents.revision`: opaque document catalog revision for diagnostics and cache decisions.
- `app`: optional app release metadata section.
- `app.releasesPath`: relative path to app release metadata.
- `app.revision`: opaque app release metadata revision.
- `bundles`: optional bundle catalog section.
- `bundles.catalogPath`: relative path to the channel bundle catalog.
- `bundles.revision`: opaque bundle catalog revision.

## Documents Catalog

Path:

```text
efa/v1/channels/<channel>/documents/catalog.json
```

Example:

```json
{
  "schemaVersion": 1,
  "version": 1,
  "entries": [
    {
      "id": "remote-announcement-2026-05-maintenance",
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
          "bodyPath": "documents/body/en/remote-announcement-2026-05-maintenance.md"
        },
        "zh": {
          "title": "维护公告",
          "summary": "一条简短的远程公告摘要。",
          "bodyPath": "documents/body/zh/remote-announcement-2026-05-maintenance.md"
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
- `id`: stable document id.
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

Path:

```text
efa/v1/channels/<channel>/app/releases.json
```

Example:

```json
{
  "schemaVersion": 1,
  "releases": [
    {
      "platform": "android",
      "channel": "alpha",
      "appVersion": "0.0.2",
      "buildNumber": 2,
      "publishedAt": "2026-05-20T00:00:00Z",
      "minimumSupportedVersion": "0.0.1",
      "releaseNoteDocumentId": "version-alpha-0-0-2",
      "downloadUrl": "https://example.com/eve-fit-assistant-0.0.2.apk",
      "sha256": "optional-apk-sha256"
    }
  ]
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `releases`: release metadata entries.
- `platform`: target platform, such as `android`.
- `channel`: release channel.
- `appVersion`: user-facing app version.
- `buildNumber`: platform build number.
- `publishedAt`: UTC release publication timestamp.
- `minimumSupportedVersion`: optional minimum app version that remains supported.
- `releaseNoteDocumentId`: optional document id for release notes.
- `downloadUrl`: optional external download URL.
- `sha256`: optional SHA-256 for the externally downloaded app artifact.

App release metadata is informational. It must not trigger in-app binary hot updates, runtime code
replacement, or dynamic Dart, native, or JavaScript loading.

## Bundle Catalog

Path:

```text
efa/v1/channels/<channel>/bundles/catalog.json
```

Example:

```json
{
  "schemaVersion": 1,
  "artifacts": [
    {
      "artifactId": "tranquility-full-20260520",
      "bundleId": "tranquility",
      "variant": "full",
      "appVersion": "0.0.1+1",
      "gameVersion": "2026.05",
      "gameBuild": "1234567",
      "gameRegion": "global",
      "gameBranch": "release",
      "gameServer": "tranquility",
      "generatedAt": "2026-05-20T00:00:00Z",
      "artifactPath": "bundles/tranquility/tranquility-full-20260520.zip",
      "artifactSize": 123456789,
      "artifactSha256": "zip-sha256",
      "manifestPath": "bundles/tranquility/tranquility-full-20260520.manifest.json",
      "manifestHash": "manifest-json-sha256",
      "baseBundleId": null,
      "baseManifestHash": null
    },
    {
      "artifactId": "tranquility-increment-20260521",
      "bundleId": "tranquility",
      "variant": "incremental",
      "appVersion": "0.0.1+1",
      "gameVersion": "2026.05",
      "gameBuild": "1234568",
      "gameRegion": "global",
      "gameBranch": "release",
      "gameServer": "tranquility",
      "generatedAt": "2026-05-21T00:00:00Z",
      "artifactPath": "bundles/tranquility/tranquility-increment-20260521.zip",
      "artifactSize": 123456,
      "artifactSha256": "zip-sha256",
      "manifestPath": "bundles/tranquility/tranquility-increment-20260521.manifest.json",
      "manifestHash": "new-manifest-json-sha256",
      "baseBundleId": "tranquility",
      "baseManifestHash": "required-installed-manifest-hash"
    }
  ]
}
```

Field semantics:

- `schemaVersion`: JSON schema version for this payload.
- `artifacts`: available bundle artifacts.
- `artifactId`: stable artifact id.
- `bundleId`: bundle identity installed by the app.
- `variant`: artifact variant. Supported values are `full` and `incremental`.
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
- `manifestPath`: relative path to the bundle manifest snapshot.
- `manifestHash`: SHA-256 digest of the bundle manifest snapshot.
- `baseBundleId`: bundle id that must already be installed before applying an incremental artifact.
- `baseManifestHash`: required installed manifest hash for incremental artifacts.

Bundle download and import behavior is outside this contract, but `artifactSize` and
`artifactSha256` are part of the v1 metadata contract so downloaded archives can be verified before
import.

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
channels/alpha/documents/catalog.json
documents/body/en/remote-announcement-2026-05-maintenance.md
bundles/tranquility/tranquility-full-20260520.zip
```

Rejected examples:

```text
https://evil.example.com/catalog.json
/channels/alpha/documents/catalog.json
../catalog.json
documents/../../secret.md
%2e%2e/secret.md
```

## S3-Compatible Publishing Rules

The v1 layout is designed to work as public read-only static object storage. The app never receives
S3, R2, OSS, or MinIO credentials.

Recommended publishing order:

1. Upload shared immutable resources first:

   ```text
   efa/v1/documents/body/**
   efa/v1/bundles/**
   ```

2. Upload channel-scoped catalogs next:

   ```text
   efa/v1/channels/<channel>/documents/catalog.json
   efa/v1/channels/<channel>/app/releases.json
   efa/v1/channels/<channel>/bundles/catalog.json
   ```

3. Upload the channel index last:

   ```text
   efa/v1/channels/<channel>/index.json
   ```

The repository helper follows this order when uploading a local origin to MinIO or another
S3-compatible endpoint:

```bash
./x remote publish upload --target minio
```

Recommended cache policy:

```text
efa/v1/channels/<channel>/index.json
  Cache-Control: no-cache or max-age=30

efa/v1/channels/<channel>/**/*.json
  Cache-Control: max-age=60..300

efa/v1/documents/body/**
  Cache-Control: immutable, max-age=31536000 when ids are revisioned

efa/v1/bundles/**
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
cache/remote/mock-origin/efa/v1/channels/alpha/index.json
cache/remote/mock-origin/efa/v1/channels/alpha/documents/catalog.json
cache/remote/mock-origin/efa/v1/channels/alpha/app/releases.json
cache/remote/mock-origin/efa/v1/channels/alpha/bundles/catalog.json
cache/remote/mock-origin/efa/v1/documents/body/en/remote-announcement-2026-05-maintenance.md
```

Static HTTP mock endpoint:

```bash
./x remote mock launch --backend static
```

Channel index URL:

```text
http://127.0.0.1:8765/efa/v1/channels/alpha/index.json
```

MinIO-style bucket endpoint:

```bash
./x remote mock launch --backend minio
```

Channel index URL:

```text
http://127.0.0.1:9000/efa-dev/efa/v1/channels/alpha/index.json
```

The MinIO object store persists under the configured developer data directory. With the default
configuration this is `cache/remote/minio-data/`. Change `[paths].root` or
`[remote].minio_data_dir` in `efa.dev.toml` to move that persistent store.

## Compatibility And Evolution

Additive fields may be introduced while keeping `schemaVersion: 1` when old clients can safely
ignore them. Breaking changes require a new resource root, for example:

```text
efa/v2/
```

Existing v1 clients continue to read `efa/v1/` objects and should not be redirected to a newer
resource root without an explicit client update.
