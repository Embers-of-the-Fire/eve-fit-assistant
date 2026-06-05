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
./x generate all -f
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

Data bundles are built per-workspace (e.g. `tranquility`, `serenity`) and are
**independent of the app version**. A bundle release does not require an app
version bump.

There are two types of bundle artifacts: **full bundles** (standalone) and
**incremental patches** (require a matching installed base bundle).

### Publishing a full bundle

1. Select the target workspace:
   ```bash
   ./x workspace default <workspace>
   ```

2. Build the full bundle:
   ```bash
   ./x build data
   ```
   This produces two files in `cache/workspaces/<workspace>/output/`:
   - `<bundle_id>.zip` — the complete data archive
   - `bundle_manifest.json` — snapshot manifest

3. Keep the `bundle_manifest.json`. It becomes the **baseline manifest** for the
   next patch build.

### Publishing an incremental patch

1. Start from a workspace where a full snapshot already exists.

2. Keep the previous published `bundle_manifest.json` (from either the base
   bundle or the last patch).

3. Rebuild the current data state if needed:
   ```bash
   ./x build data
   ```

4. Build the patch using the baseline manifest:
   ```bash
   ./x build increment <path/to/baseline/bundle_manifest.json>
   ```
   This produces:
   - `<bundle_id>_increment.zip` — diff-only archive
   - `bundle_manifest.json` — updated snapshot manifest

5. Publish both the increment zip **and** the new `bundle_manifest.json`, since
   the manifest becomes the baseline for the next patch in the chain.

### Important rules

- Full bundles are standalone; incremental patches are **not**.
- A patch can only be imported onto an installed bundle whose manifest matches
  the patch's baseline.
- `--no-hash` (or the `build.skip_hash` dev option) disables manifest generation.
  Builds with that flag **cannot** be used to produce patches.
- Always keep the manifest that was published with the last accepted bundle state.


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
     --id remote-announcement-2026-06-data-update \
     --title-zh "数据更新公告" \
     --title-en "Data update notice" \
     --summary-zh "本次更新包含最新 EVE 数据。" \
     --summary-en "This update includes the latest EVE data."
   ```

   Key options:
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

1. Generate the bi-lingual version documents:
   ```bash
   ./x release generate detail
   ```
   This writes `assets/content/documents/{en,zh}/version-<id>.md`.

2. Stage and publish:
   ```bash
   ./x remote prepare start
   ./x remote prepare add version \
     --zh assets/content/documents/zh/version-<id>.md \
     --en assets/content/documents/en/version-<id>.md \
     --id version-<major>-<minor>-<patch> \
     --title-zh "版本 X.Y.Z" \
     --title-en "Version X.Y.Z" \
     --summary-zh "..." \
     --summary-en "..." \
     --app-ver X.Y.Z
   ./x remote prepare diff
   ./x remote prepare verify
   ./x remote prepare commit
   ./x remote publish upload
   ```

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
    --increment <bundle_id>_increment.zip
./x remote prepare diff                # review catalog/index diffs
./x remote prepare verify              # validate internal consistency
./x remote prepare commit              # finalize the session
```

### Upload to remote storage

```bash
./x remote publish upload [--verify] [--clean]
```

- `--verify` checks SHA256 integrity of every uploaded object.
- `--clean` removes objects from the remote bucket that no catalog references.

### Promote testing → stable

```
./x remote promote
```

Follow the interactive promotion workflow to move content between channels.


## Pre-Release Checks

`./x release check` runs 10 verification gates:

| # | Gate | Severity | What it checks |
|---|------|----------|----------------|
| 1 | `version-sync` | FATAL | All version targets match `efa.config.toml` |
| 2 | `git-clean` | FATAL | Working tree clean, on `dev` branch, pushed to `origin/dev` |
| 3 | `git-tag` | WARN | Tag for current version exists and points to HEAD |
| 4 | `schema-diff` | INFO | Protobuf/schema changes since the last release tag |
| 5 | `schema-bump` | FATAL | `bundle_schema.current` was bumped when proto files changed |
| 6 | `persistence-check` | FATAL | Fit storage version changed (migration may be needed) |
| 7 | `submodule` | FATAL | `rust/lib/eve-fit-os` submodule is clean and initialized |
| 8 | `generate` | FATAL | `./x generate all -f` succeeds and produces no diff |
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
| Build full bundle | `./x build data` |
| Build patch bundle | `./x build increment <baseline_manifest>` |
| Stage announcement | `./x remote prepare add announcement --zh ... --en ...` |
| Upload to remote | `./x remote publish upload [--verify]` |


[Semver]: https://semver.org/
[Keep a Changelog]: https://keepachangelog.com/en/1.1.0/
