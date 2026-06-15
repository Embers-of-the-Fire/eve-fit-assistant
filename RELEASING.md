# Releasing

EVE Fit Assistant uses a **two-track release model**: the Android app and the data
bundles are versioned and shipped independently. You can ship a new bundle without
an app release, and vice versa.

## Version Management

The canonical version lives in `efa.config.toml` under `[version]`. It is a
[Sember]-adherent `major.minor.patch-pre_label.pre_num+build` string.
All other version targets (`pubspec.yaml`, `rust/Cargo.toml`, `pyproject.toml`)
are derived from it.

The fitting-engine submodule at `rust/lib/eve-fit-os` has its own independent versioning
and is **not** part of the sync targets.

### Show the current version

```
./x release version show
```

### Bump the version

```bash
# Bump patch and start a beta series
./x release version bump patch --pre-label beta --pre-num 1

# Bump minor and promote to a final release (clear pre-release)
./x release version bump minor --clear-pre

# Only advance the pre-release number
./x release version bump --pre-label beta --pre-num 5

# Only advance the build number
./x release version bump --build 42
```

### Sync version to all target files

```
./x release version sync
```

The target files are `pubspec.yaml`, `rust/Cargo.toml`, and `pyproject.toml`.

> The `bump` subcommand syncs automatically unless you pass `--dry-run`.


## App Release Workflow

All releases happen from the `dev` branch. The `main` and `release-*` branches
are deprecated.

### 1. Update the changelog

Open `CHANGELOG.md` and add an entry for the new version under the
`## [Unreleased]` section. The format follows [Keep a Changelog].

At minimum, comment out the `[Unreleased]` heading and add a dated heading:
`## [version] - YYYY-MM-DD`.

### 2. Bump and sync the version

```bash
./x release version bump <major|minor|patch> [--pre-label ...] [--clear-pre]
```

This updates `efa.config.toml` and syncs to all target files. Review and stage the
changes (the bump command does **not** stage them automatically).

### 3. Run pre-release checks

```bash
./x release check
```

This runs 10 gates (see [Pre-Release Checks](#pre-release-checks) below).
Fatal failures block the release unless `--force` is used.

### 4. Generate and lint

```bash
./x generate -f all
./x lint
```

Stage any resulting changes.

### 5. Commit and tag

```bash
./x release commit
```

This creates a signed commit (`chore: release v<version>`) and an annotated tag
(`v<version>`). By default, both open `$EDITOR` for message review; use `--no-edit`
to skip.

> `./x release commit` commits only **staged** changes. Stage everything you intend
> to release before running it.

### 6. Push

```bash
git push origin dev
git push origin v<version>
```

### 7. Build the APK

```bash
flutter build apk
```

The APK signing configuration in `android/app/build.gradle.kts` currently uses
debug keys. Replace the signing config before distributing the APK outside of
development.

### 8. Distribute the APK

Upload the APK from `build/app/outputs/flutter-apk/` to your distribution
channel (website, store, internal test track, etc.).


## Data Bundle Release Workflow

Data is built per-workspace (e.g. `tranquility`, `serenity`) and is
**independent of the app version**. A data release does not require an app
version bump.

Data is distributed via the V2 remote content system using content-addressed
checkout catalogs and asset stores.

### Publishing a data update

1. Select the target workspace:
   ```bash
   ./x workspace default <workspace>
   ```

2. Build the data:
   ```bash
   ./x build data
   ```
   This generates the V2 content-addressed checkout catalog at
   `cache/workspaces/<workspace>/generated/schema/checkouts/<hash>.json`
   and the asset store at `schema/assets/`.

3. Prepare and publish the remote session (see Remote Announcement Publishing below).


## Remote Announcement Publishing

Announcements are localized Markdown documents that appear in the app's Updates
feed. They support `startup` display (shown when the app launches) and are scoped
to a minimum app version.

### Preparing an announcement

1. Write the body Markdown files for each supported language (e.g. `zh` and `en`).

2. Start a prepare session and add the announcement:
   ```bash
   ./x remote prepare start
   ./x remote prepare add announcement \
     --zh docs/drafts/update.zh.md \
     --en docs/drafts/update.en.md \
     --id data-update \
     --title-zh "数据更新公告" \
     --title-en "Data update notice" \
     --summary-zh "本次更新包含最新 EVE 数据。" \
     --summary-en "This update includes the latest EVE data."
   ```

   A seconds-level timestamp suffix is automatically appended to the document ID
   (e.g. `data-update-20260605T120030Z`).  Omit `--id` to use an auto-generated
   `announcement-<timestamp>` ID.

   Key options:
   - `--id <prefix>` — optional topic prefix (timestamp suffix appended automatically). Defaults to `announcement`.
   - `--startup` / `--no-startup` — control whether the announcement appears on launch (default: `--startup`).
   - `--min-app-ver <version>` — scope to a minimum app version (defaults to the current `efa.config.toml` version).
   - `--all-app-ver` — publish for all app versions (writes `minAppVer` as null; mutually exclusive with `--min-app-ver`).
   - `--published-at <ISO-8601>` — set publication timestamp (defaults to now).
   - `--tag <tag>` — add tags for filtering (repeatable; defaults to `announcement`).

3. Review and finalize:
   ```bash
   ./x remote prepare diff     # review catalog/index diffs
   ./x remote prepare verify   # validate consistency
   ./x remote prepare commit   # finalize the session
   ```

4. Upload:
   ```bash
   ./x remote publish upload
   ```

### Removing an announcement

```bash
./x remote prepare start
./x remote prepare remove --document-id <remote-announcement-id>
./x remote prepare diff
./x remote prepare commit
./x remote publish upload
```


## Remote Version Publishing

Version release notes can be published to the remote server so that older
app installations can discover what has changed in a new release.

### Publishing a version note

Version document IDs are auto-generated as `version-{appVer}` (e.g. `version-0.0.3`).
Pass `--id` to override.

1. Generate the bi-lingual version documents:
   ```bash
   ./x release changelog detail --no-edit
   ```

2. Build the bundled document assets so the new version notes are included
   in the APK:
   ```bash
   ./x generate docs
   ```

3. Stage to remote so older app installations can discover the new version:
   ```bash
   ./x release changelog stage --commit
   ./x remote publish upload
   ```

   Without `--commit`, the `stage` command shows a diff and prints the
   manual commit/upload commands for review before finalizing.

### Removing a version note

```bash
./x remote prepare start
./x remote prepare remove --document-id <version-document-id>
./x remote prepare diff
./x remote prepare commit
./x remote publish upload
```


## Remote Bundle Publishing

Bundles can be uploaded to S3-compatible storage (Cloudflare R2, MinIO, etc.).
Configure the remote under `[remote.s3]` in `efa.dev.toml`.

### Prepare a publish session

```bash
./x remote prepare start               # start a session
./x remote prepare add bundle \        # add a full bundle
    --full <bundle_id>.zip \
    --manifest <bundle_manifest.json>
./x remote prepare add bundle \        # optionally add its increment
    --full <bundle_id>.zip \
    --manifest <bundle_manifest.json> \
    --increment <bundle_id>_increment.zip
./x remote prepare diff                # review catalog/index diffs
./x remote prepare verify              # validate internal consistency
./x remote prepare commit              # finalize the session
```

The `--artifact-id` option is now **optional**. When omitted, the artifact ID is auto-generated
from the bundle descriptor as `data-{gameServer}-{gameBuild}` (e.g. `data-tranquility-2203108`).
For incremental bundles the suffix `-inc` is appended.

### Upload to remote storage

```bash
./x remote publish upload [--verify] [--clean]
```

- `--verify` checks SHA256 integrity of every uploaded object.
- `--clean` runs post-upload garbage collection to prune old generations and unreferenced content
  (no longer deletes the bucket before uploading — the publish is safe to retry if interrupted).

### Promote testing → stable

```
./x remote promote
```

Follow the interactive promotion workflow to move content between channels.


## Schema V2 Data & Release Workflow

Schema V2 replaces the v1 data-bundle system with **content-addressed checkouts**.
Checkout data is generated locally, published to remote storage at
`efa/v2/<channel>/`, and consumed by the app through branch/checkout resolution.
App releases (APKs) are published alongside with content-addressed storage.

See the [schema specification](agent/schemav2/spec.md) for the full
storage contract and hash algorithm.

### V2 Checkout Data Generation

`./x build data` produces a v2 schema checkout alongside the workspace build output:

- `build/<workspace>/schema/checkouts/<hash>.json` — checkout catalog (file manifest + metadata)
- `build/<workspace>/schema/assets/` — content-addressed asset files

To generate a checkout standalone:

```bash
./x generate schema --dir <build_dir> --server <server_id>
```

The output lands at `<build_dir>/schema/`. The checkout hash is a SHA-256
digest of the sorted file manifest — two builds with identical data produce
the same checkout ID.

### V2 Remote Publishing

Remote publishing uses a session lifecycle under the `./x remote prepare`
sub-group (targeting `efa/v2/<channel>/`):

#### 1. Start a session

```bash
./x remote prepare prepare \
  --backend s3 \
  --channel stable \
  --description "Serenity update 2026-06-13"
```

`--backend` accepts `minio` (local development) or `s3` (production R2/OSS/S3-compatible).

#### 2. Add server data

Register one or more server + checkout catalogs:

```bash
./x remote prepare add-resources \
  --checkout build/serenity/schema/checkouts/<hash>.json \
  --server serenity \
  --name-en "Serenity" \
  --name-zh "晨曦"
```

Repeat `--checkout` to register multiple checkouts for the same server.

#### 3. Add an APK release

```bash
./x remote prepare add-release \
  --version "0.2.0" \
  --apk build/app/outputs/flutter-apk/app-release.apk \
  --announcement <announcement-id>
```

The APK is hashed (SHA-256) and stored content-addressed at
`resources/releases/<2c hash>/<hash>` under the remote storage root.

`--announcement` is optional — provides a link to a version-update announcement.

#### 4. Publish

```bash
./x remote prepare publish
```

Uploads the merged tree to S3/R2, activates the generation via
`manifest/index.json`, and appends to `manifest/generations.json`.

### V2 Release Catalog Format

The `releases/catalog.json` in each generation describes available releases:

```json
{
  "releasesVersion": 1,
  "releases": {
    "<release hash>": {
      "id": "<release hash>",
      "createdAt": "2026-06-13T00:00:00Z",
      "version": "0.2.0",
      "offering": ["apk"],
      "downloadHash": "<apk content hash>"
    }
  }
}
```

The full release item record (containing per-platform file hashes) is stored
content-addressed at `resources/releases/<2c>/<downloadHash>` with a nested
`files: {offering: {platform: hash}}` structure.

The app client discovers releases via the release catalog, compares versions
semantically, and downloads the APK through the same content-addressed
resolution path as data assets.

### Updated Release Checks

The `./x release check` schema-diff gate now detects v2-specific model changes
in addition to protobuf and persistence changes:

| Change Detected | Severity | Blocks Release? | Remediation |
|-----------------|----------|-----------------|-------------|
| `lib/storage/repo/models/` modified, `[schema].schema_version` NOT bumped | BREAKING | **Yes** | Bump `[schema].schema_version` in `efa.config.toml` |
| `lib/storage/repo/models/` modified, `[schema].schema_version` bumped | BREAKING | **Yes** (by `has_breaking`) | `--force` after confirming |
| `lib/features/remote_content/endpoint.dart` modified | BREAKING | **Yes** | Verify client/server compatibility, then `--force` |
| `lib/storage/repo/migration/` modified | INFO | No | Informational only |


## Pre-Release Checks

`./x release check` runs 10 verification gates:

| # | Gate | Severity | What it checks |
|---|------|----------|----------------|
| 1 | `version-sync` | FATAL | All version targets match `efa.config.toml` |
| 2 | `git-clean` | FATAL | Working tree clean, on `dev` branch, pushed to `origin/dev` |
| 3 | `git-tag` | WARN | Tag for current version exists and points to HEAD |
| 4 | `schema-diff` | FATAL | Breaking schema/endpoint/model changes (DART_MODEL, REMOTE_API, protobuf) require version bumps or `--force` |
| 5 | `schema-bump` | FATAL | `[schema].schema_version` was bumped when `lib/storage/repo/models/` files changed |
| 6 | `persistence-check` | FATAL | Fit storage version changed (migration may be needed) |
| 7 | `submodule` | FATAL | `rust/lib/eve-fit-os` submodule is clean and initialized |
| 8 | `generate` | FATAL | `./x generate -f all` succeeds and produces no diff |
| 9 | `lint` | FATAL | `./x lint` passes |
| 10 | `changelog` | WARN | `CHANGELOG.md` has an entry for the current version |

FATAL failures block release unless `--force` is used (they downgrade to WARN).

Run with `--since <tag>` to compare against a specific tag instead of
auto-detecting the last release tag.


## Quick Reference

| Action | Command |
|--------|---------|
| Show current version | `./x release version show` |
| Bump version | `./x release version bump <level> [--pre-label ...]` |
| Sync version targets | `./x release version sync` |
| Pre-release checks | `./x release check [--force]` |
| Commit and tag | `./x release commit [--no-edit]` |
| Build data | `./x build data` |
| Generate V2 schema checkout | `./x generate schema --dir <dir> --server <id>` |
| Start V2 remote session | `./x remote prepare prepare --backend s3 --channel stable --description "..."` |
| Add V2 server data | `./x remote prepare add-resources --checkout <path> --server <id> --name-en "..." --name-zh "..."` |
| Add V2 APK release | `./x remote prepare add-release --version "0.2.0" --apk <path> --announcement <id>` |
| Publish V2 generation | `./x remote prepare publish` |
| Run remote GC | `./x remote publish gc [--dry-run] [--keep-generations N]` |


[Semver]: https://semver.org/
[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
