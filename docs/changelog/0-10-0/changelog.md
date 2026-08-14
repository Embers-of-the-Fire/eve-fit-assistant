## [v0.10.0] - 2026-08-14

### Added

- **update:** background app self-update with system notification progress (#339)
- **fit:** fold overflowing tile slide actions into dropdown and add new actions (#340)
- **fit:** group module tile dropdown actions with dividers (#342)
- **fit:** add batch slide actions to module tiles (#345)
- **fit:** place overflow dropdown before visible action on tile end slide pane (#346)
- **fit:** pin remove action at outer edge of tile end slide pane (#349)
- sort item lists by meta group and level; add meta-category filter (#355)
- **fit-link:** add cross-platform fit deep links with share landing page (#356)
- **site:** migrate share site to prerendered SvelteKit app (#361)

### Dependencies

- **deps:** bump dependencies to latest nixpkgs (#336)

### Documentation

- **manual:** document folded tile slide-action overflow menu (#344)
- **agents:** add cross-product design principles and color system (#360)

### Fixed

- **fit:** count fighter squadrons instead of fighters for tube validation (#354)
- **build:** refuse to optimise rustls kotlin component (#357)
- **app-update:** create notification action port lazily to fix web crash (#358)
- **charge:** flooring charge calculated size (#362)
- **site:** update share platform's wrangler configuration

### refactor

- **fit:** reorder module tile start slide actions to charge, dynamic, copy (#341)
