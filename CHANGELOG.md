# Changelog

All notable changes to EVE Fit Assistant are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).
## [v0.1.0-beta.5] - 2026-06-13


### Added

- **worker:** Add issue-redirect Cloudflare Worker (#130) ([#130])
- Enhance integrated report form with metadata and API support (#135) ([#135])
- **site:** Add feedback page
- Add localization and integrate `AvailableUpdateGate` dialog (#137) ([#137])
- Add CI matrix command and GitHub Actions workflow for testing (#138) ([#138])
### Fixed

- **issue:** Fix wrangler config and route config
- **site:** Fix relative link anchor## [v0.1.0-beta.4] - 2026-06-09


### Added

- Migrate SvelteKit landing page and enhance tooling setup (#125) ([#125])
- Add font scaling feature and localization to settings (#126) ([#126])
- Enhance bundle descriptor with localized names and display fields (#127) ([#127])
### Fixed

- **build:** Add setuptools config to prevent pip install failure on Cloudflare Pages## [v0.1.0-beta.3] - 2026-06-06


### Added

- Add APK output path and SHA1 utility functions (#124) ([#124])
### Fixed

- **bundle:** Use semver comparison for remote bundle app version check (#123) ([#123])## [v0.1.0-beta.2] - 2026-06-06


### Added

- **remote:** Enable remote content fetcher by default
- Add log collection page and localization keys (#120) ([#120])
### Documentation

- Add feature introduction images to documentation (#121) ([#121])
### Fixed

- Strip YAML frontmatter from remote document bodies (#122) ([#122])## [v0.1.0-beta.1] - 2026-06-06


### Added

- Detect system locale (#71) ([#71])
- Add advanced fit validation and surface issues in UI (#72) ([#72])
- **character:** Use slide actions for profile rows (#74) ([#74])
- Enhance bundle skill profile management and validation (#75) ([#75])
- Restyle skill group selector and editor layout (#77) ([#77])
- Add configurable list return behavior for nested selectors (#78) ([#78])
- Add bundle impact analysis and warning preferences (#79) ([#79])
- Add mock origin fixtures and document launch workflow (#90) ([#90])
- Enhance remote content settings with controls and persistence (#91) ([#91])
- Add S3 publish command and document workflow (#92) ([#92])
- Sync remote documents and improve error logging (#93) ([#93])
- Add and test installed bundle verification service and UI (#94) ([#94])
- Enhance remote bundle management and documentation (#95) ([#95])
- Enhance remote bundle selection and recommendation logic (#96) ([#96])
- Enhance remote bundle import with progress reporting and UI updates (#98) ([#98])
- Stabilize and reload active bundle providers (#99) ([#99])
- Implement centralized Dio factory, ETag caching, and incremental fetch (#100) ([#100])
- Implement adaptive grid layout for workspace shortcut cards (#101) ([#101])
- Enable ship hull inspection and add hyperlink handler in description (#103) ([#103])
- Add startup bundle update notification dialog and localization (#105) ([#105])
- Enhance document storage with unread tracking and versioning features (#104) ([#104])
- Refactor remote configuration to support nested MinIO and S3 models (#106) ([#106])
- Add session management module and enhance remote CLI features (#107) ([#107])
- Refactor app version retrieval and remove `pubspec.yaml` from assets (#108) ([#108])
- Enhance remote upload with integrity verification and config options (#110) ([#110])
- Add minAppVer warning features and version comparison utilities (#111) ([#111])
- Implement bundle schema versioning and related UI updates (#112) ([#112])
- Introduce Channel enum and migrate alpha to testing across platforms (#113) ([#113])
- Add SECURITY.md and implement report page features (#115) ([#115])
- Enhance release management with versioning, syncing, and checks (#114) ([#114])
- Enhance changelog generation with git-cliff integration (#116) ([#116])
- Add version publishing model and CLI support for remote operations (#117) ([#117])
- Add write-changelog opencode command
- Implement auto-generated IDs and generation support for remote features (#118) ([#118])
- Refactor session management and validation in remote module (#119) ([#119])
### Changed

- Enhance developer configuration and environment commands (#89) ([#89])
### Documentation

- **readme:** Update alpha development guide (#70) ([#70])
- **remote-content:** Document local baseline (#87) ([#87])
- **remote-content:** Define v1 storage contract (#88) ([#88])
- Update releasing guide
### Fixed

- **bundle-manager:** Preserve bundle title in narrow layouts (#73) ([#73])
- **skills:** Treat missing alpha max as unavailable (#76) ([#76])
- **http:** Handle stale ETag in fetchRemoteJson on hot restart (#102) ([#102])
- **cli:** Skip bucket creation and anonymous policy for S3 target
- Fix flutter build properties and include build number in version (#109) ([#109])
- **release:** Scope tag discovery to current branch
- **release:** Correct -f flag position in generate all command
- **remote:** Handle empty S3 bucket in fetch_remote_state_s3
- **remote:** Derive artifact_id from bundleId instead of gameServer
- **remote:** Fix S3 publish upload failures on empty R2 buckets
## [Unreleased]

### Added

-

