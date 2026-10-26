## [v1.0.0-beta.1] - 2026-10-25

### Added

- **release:** dual-track release versioning (testing/stable) (#521)
- **remote:** stable data channel with promotion and cadence tiers (#527)
- **app:** add channel switch dialog with efa:// action link and startup notice (#532)

### Chore

- **nix:** let uv manage the CPython interpreter (#519)
- **docs:** remove invalid dangling reference in code and update agent guideline

### Dependencies

- **deps:** update github actions (#529)

### Fixed

- **deps:** update dependency fast_immutable_collections to v12 (#516)
- **remote:** raise on non-missing head download failures during sync (#534)
