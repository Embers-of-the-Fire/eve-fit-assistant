import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { parseArgs } from "node:util";

import { emitDart } from "./emit-dart.ts";
import { emitTypeScript } from "./emit-ts.ts";
import { loadSchema } from "./schema.ts";

const USAGE =
    "Usage: acl-codegen --schema <schema.yaml> [--ts <out.ts>] [--dart <out.dart>] " +
    "[--ts-runtime-import <specifier>]";

async function main(): Promise<void> {
    const { values } = parseArgs({
        options: {
            schema: { type: "string" },
            ts: { type: "string" },
            dart: { type: "string" },
            "ts-runtime-import": { type: "string", default: "acl-ts" },
        },
    });
    if (values.schema === undefined || (values.ts === undefined && values.dart === undefined)) {
        console.error(USAGE);
        process.exit(1);
    }
    const schema = loadSchema(await readFile(values.schema, "utf8"));
    const outputs: [string | undefined, string][] = [
        [values.ts, emitTypeScript(schema, { runtimeImport: values["ts-runtime-import"] })],
        [values.dart, emitDart(schema)],
    ];
    for (const [path, content] of outputs) {
        if (path === undefined) {
            continue;
        }
        await mkdir(dirname(path), { recursive: true });
        await writeFile(path, content);
        console.log(`Generated ${path}`);
    }
}

main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
});
