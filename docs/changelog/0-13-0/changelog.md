## [v0.13.0] - 2026-09-03

### Added

- **platform:** reproduce fits with the latest server snapshot on consent (#438)

### Changed

- **platform:** freeze snapshots via a registration counter, not `COUNT(*)` (#441)

### Fixed

- **app:** render subsystem section only when subsystems are equipped (#431)
- **app:** stop auto-opening the post page after fit upload (#432)
- **engine:** resolve in-fit stats for fighter squadrons beyond the first (#439)

### refactor

- **platform:** rebuild snapshot store with binary hashes and dense id rows (#436)
