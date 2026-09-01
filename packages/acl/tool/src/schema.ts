import { parse } from "yaml";

import type { AclAction, AclDomain, AclQualifier, AclRole, AclSchema } from "./model.ts";
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

// Top-level key reserved for the roles section; a domain cannot use it.
const ROLES_KEY = "roles";

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
    let rolesValue: unknown;
    for (const [name, value] of Object.entries(document)) {
        if (name === ROLES_KEY) {
            rolesValue = value;
            continue;
        }
        domains.push(parseDomain(name, value));
    }
    if (domains.length === 0) {
        throw new AclSchemaError("<root>", "schema must declare at least one domain");
    }
    // Roles are parsed last: their tokens are validated against the domains.
    const roles = rolesValue === undefined ? [] : parseRoles(rolesValue, domains);
    return { domains, roles };
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

function parseRoles(value: unknown, domains: AclDomain[]): AclRole[] {
    const path = ROLES_KEY;
    if (!isRecord(value)) {
        throw new AclSchemaError(path, "expected a map of roles");
    }
    const roles: AclRole[] = [];
    for (const [roleName, roleValue] of Object.entries(value)) {
        roles.push(parseRole(roleName, roleValue, domains));
    }
    if (roles.length === 0) {
        throw new AclSchemaError(
            path,
            "must not be empty; omit the key for a schema without roles",
        );
    }
    return roles;
}

function parseRole(name: string, value: unknown, domains: AclDomain[]): AclRole {
    const path = `${ROLES_KEY}.${name}`;
    if (!isValidName(name)) {
        throw new AclSchemaError(path, `invalid role name "${name}"`);
    }
    if (!isRecord(value)) {
        throw new AclSchemaError(path, "expected a map with description and tokens");
    }
    rejectUnknownKeys(value, ["description", "tokens", "default"], path);
    const description = requireDescription(value.description, `${path}.description`);
    if (value.default !== undefined && typeof value.default !== "boolean") {
        throw new AclSchemaError(`${path}.default`, "expected a boolean");
    }
    if (!Array.isArray(value.tokens)) {
        throw new AclSchemaError(`${path}.tokens`, "expected a list of token literals");
    }
    const tokens: string[] = [];
    for (const token of value.tokens) {
        if (typeof token !== "string") {
            throw new AclSchemaError(`${path}.tokens`, "expected a list of token literals");
        }
        validateRoleToken(token, domains, `${path}.tokens`);
        tokens.push(token);
    }
    if (tokens.length === 0) {
        throw new AclSchemaError(`${path}.tokens`, "a role must grant at least one token");
    }
    return { name, description, tokens, isDefault: value.default === true };
}

// A role token is valid only when it references a declared action exactly:
// unqualified actions take `{domain}:{action}`, qualified actions require one
// of their declared qualifiers.
function validateRoleToken(token: string, domains: AclDomain[], path: string): void {
    const parts = token.split(":");
    if (parts.length < 2 || parts.length > 3) {
        throw new AclSchemaError(path, `invalid token literal "${token}"`);
    }
    const [domainName, actionName, qualifier] = parts;
    const domain = domains.find((candidate) => candidate.name === domainName);
    const action = domain?.actions.find((candidate) => candidate.name === actionName);
    if (action === undefined) {
        throw new AclSchemaError(path, `token "${token}" is not defined by the schema`);
    }
    if (action.qualifiers.length === 0) {
        if (qualifier !== undefined) {
            throw new AclSchemaError(path, `token "${token}" qualifies an unqualified action`);
        }
        return;
    }
    if (!action.qualifiers.some((candidate) => candidate.name === qualifier)) {
        throw new AclSchemaError(
            path,
            `token "${token}" must carry a declared qualifier of "${domainName}:${actionName}"`,
        );
    }
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
