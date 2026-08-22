# efa_constant

Scope: dependency-free EVE constant definitions exposed as `package:efa_constant/eve.dart`
(`EveConst*` classes and `EveDogmaUnitId`).

- `eve_dogma_unit_generated.dart` is tracked; regenerate it with
  `./x generate values dogma-units` when its source data changes.
- `eve_attr_generated.dart` is generated and gitignored.
- Keep this package dependency-free unless a design change explicitly requires otherwise.

Validation:

```sh
./x generate values dogma-units
```
