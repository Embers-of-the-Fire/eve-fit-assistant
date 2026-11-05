# efa_constant

Scope: dependency-free EVE constant definitions exposed as `package:efa_constant/eve.dart`
(`EveConst*` classes and `EveDogmaUnitId`).

- Keep this package dependency-free unless a design change explicitly requires otherwise.
- `eve_attr_generated.dart` is generated and gitignored — never edit or check it in.
- `eve_dogma_unit_generated.dart` is tracked; regenerate it with
  `./x generate values dogma-units` when its source data changes instead of editing by hand.

## Docs

- Data workspaces and versioning: [docs/dev/data-versioning.md](../../docs/dev/data-versioning.md)
- Validation: `./x generate values dogma-units`.
