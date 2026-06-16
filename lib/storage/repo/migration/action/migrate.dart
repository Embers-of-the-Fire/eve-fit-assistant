/// Barrel export for migration action sub-module.
///
/// ## Migration Stages (dependencies → downstream)
///
/// 1. **MigrateProgress** — checkpoint state machine. Loads/saves `.migration_progress.json`.
/// 2. **MigrateFits** — v2 upgrade: replaces `bundleId`/`bundleSnapshot` with `CheckoutRef`.
///    Reads from old `fittings/`, writes migrated files to `runtime/v2/fittings/`.
/// 3. **MigrateCharacters** — v2 upgrade for character records. Same old→new pattern.
/// 4. **MigrateService** — orchestration. Runs stages in dependency order
///    (fits → characters → finalize) with checkpoint-based resumption.
///    Finalize writes `schema_version.json` and deletes old `fittings/` and `characters/`.
///
library;

export "migrate_characters.dart";
export "migrate_fits.dart";
export "migrate_runner.dart";
export "models.dart";
export "progress.dart";
export "service.dart";
