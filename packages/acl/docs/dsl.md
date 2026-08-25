# ACL Schema DSL

The code generator consumes a single YAML document describing permission
domains, their actions, and optional qualifiers.

## Format

```yaml
<domain>:
  description: <string>            # required, non-empty
  actions:                         # required, at least one
    <action>:
      description: <string>        # required, non-empty
      qualifiers:                  # optional map of <qualifier>: <description>
        <qualifier>: <string>
```

Example:

```yaml
post:
  description: |
    Post management permission group.
  actions:
    create:
      description: Create posts.
    delete:
      description: Delete posts.
      qualifiers:
        own: Manage owned posts.
        all: Manage all posts.
```

## Rules

- Names (domains, actions, qualifiers) must match `^[a-z][a-z0-9_]*$`.
  Declaration order is preserved in the generated bindings.
- Descriptions may be multiline (block scalars); they are trimmed and reused
  as doc comments in the generated code.
- An action with a `qualifiers` map produces tokens that **must** carry one of
  the declared qualifiers (`post:delete:own`). An action without it produces
  qualifier-free tokens (`post:create`).
- Unknown keys, empty descriptions, empty `qualifiers` maps, and invalid names
  are rejected with an `AclSchemaError` naming the offending path
  (e.g. `post.delete.qualifiers`).

## Generated names

snake_case schema names become PascalCase type names:

| Schema element | TypeScript | Dart |
| -------------- | ---------- | ---- |
| qualifier union of `post:delete` | `PostDeleteQualifier` | `PostDeleteQualifier` (enum) |
| token for `post:delete` | `` PostDelete = `post:delete:${...}` `` | `PostDelete` (final class) |
| token union of domain `post` | `PostToken` | — (classes share `AclToken`) |
| whole schema | `AclToken`, `AclActionMap`, `aclTokens`, `isAclToken`, `createAcl` | `AclToken`, `parseAclToken`, `AclTokenQueries` extension |
