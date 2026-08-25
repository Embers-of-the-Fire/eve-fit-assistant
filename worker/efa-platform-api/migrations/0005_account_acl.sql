-- Placeholder ACL roles on the account row. JSON array of role names defined
-- by packages/efa_acl (e.g. '["user"]'); the source of truth for account
-- permissions, mirrored into the AUTH_KV cache by the API worker. The column
-- default must match `aclDefaultRoles` in the generated efa_acl bindings —
-- test/auth/account.test.ts asserts this.
ALTER TABLE users ADD COLUMN acl_roles TEXT NOT NULL DEFAULT '["user"]';
