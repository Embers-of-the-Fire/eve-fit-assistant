## [v1.0.0-beta.2] - 2026-10-29

### Added

- **resolution:** single-source the Resource Resolution Schema (#544)
- display 3D model for ship (#523)

### Chore

- **lint:** turn off NonNull assertion in javascript tests
- **lint:** update biome lint configuration for svelte
- **lint:** update biome version

### Dependencies

- **deps:** update dependency python to v3.15.1 (#522)
- **deps:** update js dependencies (pnpm) (#526)
- **deps:** update renovate configuration to bump python version
- **deps:** update github actions (#546)
- **deps:** update rust dependencies (cargo) (#528)

### Fixed

- **app:** handle system gesture navigation with edge-to-edge (#538)
- **deps,python:** fix python dependency resolution on CI/CD
- **bootstrap:** pin protoc-gen-dart for hermetic protobuf codegen (#547)
- **bootstrap:** fill missing non-default localizations from curated patches (#549)

### deps

- **site:** migrate homepage to SvelteKit 3 (#543)
- **python,nix:** bump python version to 3.15 and sync nixpkgs to latest unstable
- **python:** degrade to python 3.14 (#550)

### refactor

- **remote:** replace MinIO with RustFS and boto3 (#548)
