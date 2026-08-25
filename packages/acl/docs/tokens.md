# ACL Tokens

## Grammar

```text
token     = domain ":" action [ ":" qualifier ]
domain    = action = qualifier = [a-z] [a-z0-9_]*
```

A token has exactly two segments (unqualified action) or three segments
(qualified action). Empty segments, uppercase letters, dashes, and extra
segments are malformed input.

`parseToken` (both runtimes) validates this grammar only and throws
`AclTokenError` / `AclTokenFormatException` on malformed input. Whether the
segments actually exist is a schema-level concern, checked by the generated
`isAclToken` (TS) / `parseAclToken` (Dart).

## Semantics

Matching is **exact**:

- `has(token)` is exact string membership, qualifier included.
- A broader qualifier never implies a narrower one: a set containing
  `post:delete:all` does **not** answer `own` queries.
- An unqualified token (`post:create`) never matches a qualified action key
  (`post:delete`) and vice versa.

## Queries

`can("{domain}:{action}")` answers at the action level:

| Action kind | Granted | Not granted |
| ----------- | ------- | ----------- |
| unqualified | `true` | `false` |
| qualified | matched qualifiers (`("own" \| "all")[]` in TS, `Set<PostDeleteQualifier>` in Dart) | `false` (TS) / `null` (Dart generated helpers) |

Typed wrappers come from the generated bindings:

```ts
acl.can("post:delete"); // ("own" | "all")[] | false
```

```dart
acl.canPostDelete(); // Set<PostDeleteQualifier>?
```
