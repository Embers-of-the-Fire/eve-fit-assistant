# Resource Patches

Patches are those data cannot be generated via generic workflow
and must be edited and updated manually.

**TOC:**
- [Resource Patches](#resource-patches)
  - [Tactical Mode](#tactical-mode)

## Tactical Mode

Tactical modes are defined in the client code and could not be exported
or extracted unless one decompile the `code.ccp`.
So, we choose to manually maintain the tactical mode.

**Example File:** [`patches/tactical_mode.yaml`](../../data/resources/example/patches/tactical_mode.yaml)

**Schema:**
```yaml
<ship id>:
  modes:
    - variant: defense | speed | target
      typeId: <type id>
```

**Note:** In eve's client code, the `target` variant is called `stanceSniper`.
