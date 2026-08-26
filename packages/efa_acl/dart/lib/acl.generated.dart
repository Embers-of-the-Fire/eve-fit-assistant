// GENERATED CODE - DO NOT EDIT BY HAND. Regenerate with `acl-codegen`.

import "package:acl/acl.dart";

/// Qualifiers for `post:delete`.
enum PostDeleteQualifier {
  /// Delete posts published by the account itself.
  own,

  /// Delete any post on the platform.
  all,
}

/// Qualifiers for `comment:delete`.
enum CommentDeleteQualifier {
  /// Delete comments written by the account itself.
  own,

  /// Delete any comment on the platform.
  all,
}

/// Base type for all ACL tokens defined by this schema.
sealed class AclToken {
  const AclToken();

  /// Encodes this token into its `{domain}:{action}[:{qualifier}]` string form.
  String encode();
}

/// Publish fit posts to the platform.
final class PostCreate extends AclToken {
  const PostCreate();

  @override
  String encode() => "post:create";
}

/// Delete fit posts.
final class PostDelete extends AclToken {
  const PostDelete(this.qualifier);

  /// The qualifier narrowing this action.
  final PostDeleteQualifier qualifier;

  @override
  String encode() => "post:delete:${qualifier.name}";
}

/// Post comments on fit post threads.
final class CommentCreate extends AclToken {
  const CommentCreate();

  @override
  String encode() => "comment:create";
}

/// Delete comments.
final class CommentDelete extends AclToken {
  const CommentDelete(this.qualifier);

  /// The qualifier narrowing this action.
  final CommentDeleteQualifier qualifier;

  @override
  String encode() => "comment:delete:${qualifier.name}";
}

/// Assign or revoke account permission roles.
final class AdminManageRoles extends AclToken {
  const AdminManageRoles();

  @override
  String encode() => "admin:manage_roles";
}

/// Parses [token] into a schema-defined [AclToken], or returns `null` when
/// the token is not defined by this schema.
AclToken? parseAclToken(String token) => switch (token.split(":")) {
  ["post", "create"] => const PostCreate(),
  ["post", "delete", final qualifier] => switch (qualifier) {
    "own" => const PostDelete(PostDeleteQualifier.own),
    "all" => const PostDelete(PostDeleteQualifier.all),
    _ => null,
  },
  ["comment", "create"] => const CommentCreate(),
  ["comment", "delete", final qualifier] => switch (qualifier) {
    "own" => const CommentDelete(CommentDeleteQualifier.own),
    "all" => const CommentDelete(CommentDeleteQualifier.all),
    _ => null,
  },
  ["admin", "manage_roles"] => const AdminManageRoles(),
  _ => null,
};

/// Typed queries over an [Acl] token set for this schema.
extension AclTokenQueries on Acl {
  /// Whether this set contains [token] exactly, qualifier included.
  bool hasToken(AclToken token) => has(token.encode());

  /// Publish fit posts to the platform.
  bool canPostCreate() => can("post:create") as bool;

  /// Delete fit posts.
  Set<PostDeleteQualifier>? canPostDelete() {
    final matched = can("post:delete");
    if (matched is! Set<String>) {
      return null;
    }
    return {for (final qualifier in matched) PostDeleteQualifier.values.byName(qualifier)};
  }

  /// Post comments on fit post threads.
  bool canCommentCreate() => can("comment:create") as bool;

  /// Delete comments.
  Set<CommentDeleteQualifier>? canCommentDelete() {
    final matched = can("comment:delete");
    if (matched is! Set<String>) {
      return null;
    }
    return {for (final qualifier in matched) CommentDeleteQualifier.values.byName(qualifier)};
  }

  /// Assign or revoke account permission roles.
  bool canAdminManageRoles() => can("admin:manage_roles") as bool;
}

/// Permission roles defined by this schema.
enum AclRole {
  /// Base role granted to every account.
  user([
    PostCreate(),
    PostDelete(PostDeleteQualifier.own),
    CommentCreate(),
    CommentDelete(CommentDeleteQualifier.own),
  ]),

  /// Can moderate posts published by any account.
  moderator([
    PostCreate(),
    PostDelete(PostDeleteQualifier.own),
    PostDelete(PostDeleteQualifier.all),
    CommentCreate(),
    CommentDelete(CommentDeleteQualifier.own),
    CommentDelete(CommentDeleteQualifier.all),
  ]),

  /// Full platform administration.
  admin([
    PostCreate(),
    PostDelete(PostDeleteQualifier.all),
    CommentCreate(),
    CommentDelete(CommentDeleteQualifier.all),
    AdminManageRoles(),
  ]);

  const AclRole(this.tokens);

  /// The ACL tokens this role grants.
  final List<AclToken> tokens;

  /// Looks a role up by its name, returning `null` for unknown names so a
  /// stale or mistyped stored role cannot crash a consumer.
  static AclRole? tryByName(String name) => values.asNameMap()[name];
}

/// All roles in declaration order.
const List<AclRole> aclRoles = AclRole.values;

/// Roles granted to fresh accounts by default.
const aclDefaultRoles = <AclRole>[AclRole.user];

/// Resolves role names into the union of their encoded ACL tokens. Unknown
/// role names are ignored so a stale or mistyped stored role cannot crash a
/// consumer.
Set<String> tokensForRoles(Iterable<String> roles) {
  final tokens = <String>{};
  for (final role in roles) {
    final resolved = AclRole.tryByName(role);
    if (resolved == null) {
      continue;
    }
    tokens.addAll(resolved.tokens.map((token) => token.encode()));
  }
  return tokens;
}

/// Builds an [Acl] token set from role names.
Acl aclForRoles(Iterable<String> roles) => Acl(tokensForRoles(roles));
