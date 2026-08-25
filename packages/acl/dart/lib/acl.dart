/// Runtime for ACL tokens of the form `{domain}:{action}[:{qualifier}]`.
///
/// This library is schema-agnostic; schema-defined token types, parsers, and
/// typed queries are produced by the `acl-codegen` tool (see `packages/acl/tool`).
library;

export "src/acl.dart";
export "src/token.dart";
