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

## Roles

A schema may additionally declare named **roles** — bundles of schema tokens
assignable to an account — under the reserved top-level `roles` key (a domain
cannot be named `roles`):

```yaml
roles:
  user:
    description: Base role granted to every account.
    default: true                  # optional boolean; fresh accounts start
                                   # with all roles marked default
    tokens:                        # required, non-empty list of token literals
      - post:create
      - post:delete:own
  moderator:
    description: Can remove any post.
    tokens:
      - post:create
      - post:delete:all
```

Every role token must reference a declared action exactly: unqualified actions
take `{domain}:{action}`, qualified actions must carry one of their declared
qualifiers. A role token referencing an undeclared action or qualifier is
rejected. The `roles` key is optional; omitting it yields a schema without
roles and the generated bindings skip the role surface entirely.

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
| roles section | `AclRole` (union), `aclRoles`, `aclDefaultRoles`, `isAclRole`, `tokensForRoles`, `aclForRoles` | `AclRole` (enum with `tokens` field and `tryByName`), `aclRoles`, `aclDefaultRoles`, `tokensForRoles`, `aclForRoles` |
