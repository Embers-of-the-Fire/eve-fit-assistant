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
        });
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
    ])("rejects %s", (_label, content, path) => {
        expect(() => loadSchema(content)).toThrowError(AclSchemaError);
        expect(() => loadSchema(content)).toThrowError(new RegExp(path.replace(".", "\\.")));
    });
});
