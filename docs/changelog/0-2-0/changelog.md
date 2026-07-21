## [v0.2.0] - 2026-07-22

### Added

- **release:** add --from-ref option to release relnote (#221)
- **welcome:** show download speed on separate line in setup wizard (#226)

### Changed

- **repo:** high-throughput blob download pipeline with connection pooling (#223)
- **repo:** download large blobs first in all fetch pipelines (#225)

### Chore

- migrate open preview to production level (#220)

### Fixed

- **remote:** set `Cache-Control` immutable for blob uploads (#224)

## [v0.2.0-alpha.5] - 2026-07-21

### Added

- add artifacts endpoint and download page with recommendations (#216)

### Documentation

- update builtin announcements

## [v0.2.0-alpha.4] - 2026-07-20

### Added

- **app-update:** show version details and release notes in update dialog (#209)

## [v0.2.0-alpha.3] - 2026-07-19

### Fixed

- **remote:** skip local body check for unchanged remote announcements
- **remote:** skip local body check for unchanged remote announcements (#203)
- **app-update:** first-run update detection and manual download fallback (#204)

## [v0.2.0-alpha.2] - 2026-07-18

### Added

- **remote:** migrate HTTP cache to `dio_cache_interceptor` with Hive CE (#200)

## [v0.2.0-alpha.1] - 2026-07-17

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
- add skeleton page for annoucements (#184)
- enhance CI release pipeline with preflight checks and workflows (#185)
- enhance CI workflows for release processes and documentation (#189)

### Changed

- **schema-guard:** improve migration performance and avoid loading each time (#155)

### Chore

- remove releasing guideline

### Documentation

- **readme:** update overview to reflect beta status and current feature set

### Fixed

- **description-text:** place recognizer on same TextSpan with text (#156)
- **repo-cache:** harden ETag cache persistence and 304 handling (#158)
- **remote-session:** accumulate generation resources from parent (#159)
- remove accidentally traced catalog file
- **release:** make merged release registry paths relative to merge JSON (#190)
- **cli,publisher:** skip unchanged snapshots during publish (#192)

### Refactor

- Schema V2 (#129)

### refactor

- efactor x manager into bootstrap/cli package structure (#153)
- Migrate Developer Mode to Version Page with Easter Egg Access (#168)
- refactor announcements feature and optimize feed fetching (#183)
