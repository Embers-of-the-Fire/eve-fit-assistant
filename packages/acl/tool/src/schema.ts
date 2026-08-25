import { parse } from "yaml";

import type { AclAction, AclDomain, AclQualifier, AclSchema } from "./model.ts";
import { isValidName } from "./names.ts";

/** Error thrown when a schema document is structurally invalid. */
export class AclSchemaError extends Error {
    readonly path: string;

    constructor(path: string, reason: string) {
        super(`Invalid ACL schema at "${path}": ${reason}`);
        this.name = "AclSchemaError";
        this.path = path;
    }
}

/** Parses and validates an ACL schema YAML document. */
export function loadSchema(content: string): AclSchema {
    let document: unknown;
    try {
        document = parse(content);
    } catch (error) {
        throw new AclSchemaError("<root>", `not valid YAML: ${(error as Error).message}`);
    }
    if (!isRecord(document)) {
        throw new AclSchemaError("<root>", "expected a map of domains");
    }
    const domains: AclDomain[] = [];
    for (const [name, value] of Object.entries(document)) {
        domains.push(parseDomain(name, value));
    }
    if (domains.length === 0) {
        throw new AclSchemaError("<root>", "schema must declare at least one domain");
    }
    return { domains };
}

function parseDomain(name: string, value: unknown): AclDomain {
    const path = name;
    if (!isValidName(name)) {
        throw new AclSchemaError(path, `invalid domain name "${name}"`);
    }
    if (!isRecord(value)) {
        throw new AclSchemaError(path, "expected a map with description and actions");
    }
    rejectUnknownKeys(value, ["description", "actions"], path);
    const description = requireDescription(value.description, `${path}.description`);
    if (!isRecord(value.actions)) {
        throw new AclSchemaError(`${path}.actions`, "expected a map of actions");
    }
    const actions: AclAction[] = [];
    for (const [actionName, actionValue] of Object.entries(value.actions)) {
        actions.push(parseAction(name, actionName, actionValue));
    }
    if (actions.length === 0) {
        throw new AclSchemaError(path, "domain must declare at least one action");
    }
    return { name, description, actions };
}

function parseAction(domain: string, name: string, value: unknown): AclAction {
    const path = `${domain}.${name}`;
    if (!isValidName(name)) {
        throw new AclSchemaError(path, `invalid action name "${name}"`);
    }
    if (!isRecord(value)) {
        throw new AclSchemaError(path, "expected a map with description and optional qualifiers");
    }
    rejectUnknownKeys(value, ["description", "qualifiers"], path);
    const description = requireDescription(value.description, `${path}.description`);
    const qualifiers: AclQualifier[] = [];
    if (value.qualifiers !== undefined) {
        if (!isRecord(value.qualifiers)) {
            throw new AclSchemaError(`${path}.qualifiers`, "expected a map of qualifiers");
        }
        for (const [qualifierName, qualifierDescription] of Object.entries(value.qualifiers)) {
            if (!isValidName(qualifierName)) {
                throw new AclSchemaError(
                    `${path}.qualifiers`,
                    `invalid qualifier name "${qualifierName}"`,
                );
            }
            qualifiers.push({
                name: qualifierName,
                description: requireDescription(
                    qualifierDescription,
                    `${path}.qualifiers.${qualifierName}`,
                ),
            });
        }
        if (qualifiers.length === 0) {
            throw new AclSchemaError(
                `${path}.qualifiers`,
                "must not be empty; omit the key for an unqualified action",
            );
        }
    }
    return { name, description, qualifiers };
}

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null && !Array.isArray(value);
}

function rejectUnknownKeys(record: Record<string, unknown>, allowed: string[], path: string): void {
    for (const key of Object.keys(record)) {
        if (!allowed.includes(key)) {
            throw new AclSchemaError(path, `unknown key "${key}"`);
        }
    }
}

function requireDescription(value: unknown, path: string): string {
    if (typeof value !== "string") {
        throw new AclSchemaError(path, "expected a string description");
    }
    const trimmed = value.trim();
    if (trimmed.length === 0) {
        throw new AclSchemaError(path, "description must not be empty");
    }
    return trimmed;
}
