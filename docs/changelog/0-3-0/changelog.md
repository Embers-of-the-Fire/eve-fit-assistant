## [v0.3.0] - 2026-07-24

### Added

- **site:** improve mobile navigation and download arch display (#228)
- **worker,release:** serve APK downloads with proper filename (#227)
- **fit:** display damage per hit in weapon and fighter stats (#230)
- **fit:** show inline related values in module slot rows (#234)
- **storage:** byte-based download progress with sliding-window speed (#235)
- **fit:** version native fit payload with v1 migration and v2 emit format (#244)
- **update:** add check-for-update tile on version page (#248)

### Changed

- **repo:** unify blob fetch pipelines on shared 32-worker pool (#229)

### Chore

- bump native engine version (#240)

### Fixed

- **fit:** preserve metadata edits in Fit.update (#239)
- **fit:** exclude offlined rigs from simulator payload (#247)

### refactor

- **storage:** relocate app data from documents to application support (#245)
