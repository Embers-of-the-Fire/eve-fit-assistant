## [v0.2.0-alpha.1] - 2026-07-16


### Added

- **storage-page:** improve storage and data management page (#154)
- **worker:** add email filter worker
- welcome wizard (#157)
- **history:** implement per-server generation history and cross-generation revert foundation (#160)
- **feedback:** add usage-gated feedback dialog with follow-up actions (#162)
- **remote:** deduplicate blob uploads with ResourceManager (#163)
- refactor developer tools into dedicated sub-page and update settings (#165)
- add and redesign version info page with localization support (#167)
- **setting:** enable developer mode via 5-tap easter egg on version page (#170)
- implement per-checkout and batch data update flow with fixes (#171)
- implement `ReleaseIndex`-based app update detection and APK download (#172)
- **ci:** implement CI raw data updater and enhance workflow configuration (#174)
- **ci:** add EFA Data CI release snapshot workflow (#179)
- add skeleton page for annoucements (#184)
- enhance CI release pipeline with preflight checks and workflows (#185)
- **cli:** add version sync command (#187)

### Changed

- efactor x manager into bootstrap/cli package structure (#153)
- **schema-guard:** improve migration performance and avoid loading each time (#155)
- Migrate Developer Mode to Version Page with Easter Egg Access (#168)
- **cli:** refactor CLI commands and enhance release note generation (#173)
- **ci:** refactor CI workflows for S3 config and storage alias (#180)
- **ci:** split data release workflows into cron and test variants (#181)
- refactor announcements feature and optimize feed fetching (#183)

### Chore

- update codeart
- update codeart
- remove releasing guideline
- **release:** release v0.2.0-alpha.1

### Documentation

- **readme:** update overview to reflect beta status and current feature set

### Fixed

- **description-text:** place recognizer on same TextSpan with text (#156)
- **repo-cache:** harden ETag cache persistence and 304 handling (#158)
- **remote-session:** accumulate generation resources from parent (#159)
- **cli:** redesign remote mock for from-scratch v2 workflow (#161)
- **ci:** write build.txt during raw-data update so upload step finds it (#176)
- **ci:** respect --dev-env overrides in raw-data upload and lazy-load logger config (#177)
- **ci:** pass MC_HOST credentials to all mc subprocesses (#178)
- remove accidentally traced catalog file
- **ci:** resolve base ref as remote tracking branch in release preflight

### Refactor

- Schema V2 (#129)
