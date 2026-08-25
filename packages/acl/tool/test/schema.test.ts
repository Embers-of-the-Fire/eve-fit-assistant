import { describe, expect, it } from "vitest";

import { AclSchemaError, loadSchema } from "../src/schema.ts";

describe("loadSchema", () => {
    it("parses a minimal schema", () => {
        const schema = loadSchema(`
post:
  description: Post management.
  actions:
    create:
      description: Create posts.
`);
        expect(schema).toEqual({
            domains: [
                {
                    name: "post",
                    description: "Post management.",
                    actions: [{ name: "create", description: "Create posts.", qualifiers: [] }],
                },
            ],
            roles: [],
        });
    });

    it("parses a roles section and validates its tokens against the domains", () => {
        const schema = loadSchema(`
post:
  description: Post management.
  actions:
    create:
      description: Create posts.
    delete:
      description: Delete posts.
      qualifiers:
        own: Manage owned posts.
        all: Manage all posts.

roles:
  user:
    description: Base role.
    default: true
    tokens:
      - post:create
      - post:delete:own
`);
        expect(schema.roles).toEqual([
            {
                name: "user",
                description: "Base role.",
                tokens: ["post:create", "post:delete:own"],
                isDefault: true,
            },
        ]);
    });

    it("parses qualifiers and trims block-scalar descriptions", () => {
        const schema = loadSchema(`
post:
  description: |
    Post management
    permission group.
  actions:
    delete:
      description: Delete posts.
      qualifiers:
        own: |
          Manage owned posts.
        all: Manage all posts.
`);
        expect(schema.domains[0].description).toBe("Post management\npermission group.");
        expect(schema.domains[0].actions[0].qualifiers).toEqual([
            { name: "own", description: "Manage owned posts." },
            { name: "all", description: "Manage all posts." },
        ]);
    });

    it.each([
        ["not a map root", "- just\n- a\n- list\n", "<root>"],
        ["an empty schema", "{}\n", "<root>"],
        ["invalid YAML", "post: [unclosed\n", "<root>"],
        ["an invalid domain name", "Post:\n  description: x\n  actions: {}\n", "Post"],
        ["a non-map domain", "post: 42\n", "post"],
        ["an unknown domain key", "post:\n  description: x\n  actions: {}\n  extra: 1\n", "post"],
        [
            "a missing description",
            "post:\n  actions:\n    create:\n      description: x\n",
            "post.description",
        ],
        ["an empty description", "post:\n  description: '  '\n  actions: {}\n", "post.description"],
        ["a domain without actions", "post:\n  description: x\n", "post.actions"],
        [
            "an invalid action name",
            "post:\n  description: x\n  actions:\n    Create:\n      description: x\n",
            "post.Create",
        ],
        [
            "a non-map action",
            "post:\n  description: x\n  actions:\n    create: 42\n",
            "post.create",
        ],
        [
            "an empty qualifiers map",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\n      qualifiers: {}\n",
            "post.create.qualifiers",
        ],
        [
            "an invalid qualifier name",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\n      qualifiers:\n        Own: x\n",
            "post.create.qualifiers",
        ],
        [
            "a non-string qualifier description",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\n      qualifiers:\n        own: 42\n",
            "post.create.qualifiers.own",
        ],
        [
            "a non-map roles section",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles: 42\n",
            "roles",
        ],
        [
            "an empty roles section",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles: {}\n",
            "roles",
        ],
        [
            "an invalid role name",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  User:\n    description: x\n    tokens: [post:create]\n",
            "roles.User",
        ],
        [
            "an unknown role key",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n    tokens: [post:create]\n    extra: 1\n",
            "roles.user",
        ],
        [
            "a role without tokens",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n",
            "roles.user.tokens",
        ],
        [
            "a role with an empty token list",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n    tokens: []\n",
            "roles.user.tokens",
        ],
        [
            "a role token outside the schema",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n    tokens: [post:delete]\n",
            "roles.user.tokens",
        ],
        [
            "a role token with an undeclared qualifier",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n    tokens: [post:create:own]\n",
            "roles.user.tokens",
        ],
        [
            "a role token missing a required qualifier",
            "post:\n  description: x\n  actions:\n    delete:\n      description: x\n      qualifiers:\n        own: x\nroles:\n  user:\n    description: x\n    tokens: [post:delete]\n",
            "roles.user.tokens",
        ],
        [
            "a non-boolean role default",
            "post:\n  description: x\n  actions:\n    create:\n      description: x\nroles:\n  user:\n    description: x\n    default: yes-string\n    tokens: [post:create]\n",
            "roles.user.default",
        ],
    ])("rejects %s", (_label, content, path) => {
        expect(() => loadSchema(content)).toThrowError(AclSchemaError);
        expect(() => loadSchema(content)).toThrowError(new RegExp(path.replace(".", "\\.")));
    });
});
