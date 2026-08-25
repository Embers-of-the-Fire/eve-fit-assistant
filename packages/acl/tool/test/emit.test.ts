import { readFile } from "node:fs/promises";

import { describe, expect, it } from "vitest";

import { emitDart } from "../src/emit-dart.ts";
import { emitTypeScript } from "../src/emit-ts.ts";
import { loadSchema } from "../src/schema.ts";

const exampleSchema = loadSchema(
    await readFile(new URL("../../example/acl.yaml", import.meta.url), "utf8"),
);

describe("emitTypeScript", () => {
    it("matches the snapshot for the example schema", () => {
        expect(emitTypeScript(exampleSchema, { runtimeImport: "acl-ts" })).toMatchSnapshot();
    });
});

describe("emitDart", () => {
    it("matches the snapshot for the example schema", () => {
        expect(emitDart(exampleSchema)).toMatchSnapshot();
    });
});
