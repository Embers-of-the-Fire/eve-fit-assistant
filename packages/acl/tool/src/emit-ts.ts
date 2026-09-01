import type { AclAction, AclDomain, AclRole, AclSchema } from "./model.ts";
import { pascalCase } from "./names.ts";

const HEADER = "// GENERATED CODE - DO NOT EDIT BY HAND. Regenerate with `acl-codegen`.";

/** Options for the TypeScript emitter. */
export interface EmitTsOptions {
    /** Module specifier used to import the `acl-ts` runtime. */
    runtimeImport: string;
}

/** Emits TypeScript bindings for a validated ACL schema. */
export function emitTypeScript(schema: AclSchema, options: EmitTsOptions): string {
    const chunks: string[] = [HEADER, `import { Acl } from "${options.runtimeImport}";`];

    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            if (action.qualifiers.length > 0) {
                chunks.push(emitQualifierUnion(domain, action));
            }
        }
    }

    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            chunks.push(emitActionToken(domain, action));
        }
        chunks.push(emitDomainToken(domain));
    }

    chunks.push(emitTokenUnion(schema));
    chunks.push(emitActionMap(schema));
    chunks.push(emitTokenList(schema));
    chunks.push(emitTokenGuard());
    chunks.push(emitFactory());
    if (schema.roles.length > 0) {
        for (const chunk of emitRoles(schema.roles)) {
            chunks.push(chunk);
        }
    }

    return `${chunks.join("\n\n")}\n`;
}

function qualifierUnionName(domain: AclDomain, action: AclAction): string {
    return `${pascalCase(domain.name)}${pascalCase(action.name)}Qualifier`;
}

function actionTokenName(domain: AclDomain, action: AclAction): string {
    return `${pascalCase(domain.name)}${pascalCase(action.name)}`;
}

function domainTokenName(domain: AclDomain): string {
    return `${pascalCase(domain.name)}Token`;
}

function tsDoc(lines: string[]): string {
    if (lines.length === 1) {
        return `/** ${lines[0]} */`;
    }
    return ["/**", ...lines.map((line) => (line === "" ? " *" : ` * ${line}`)), " */"].join("\n");
}

function descriptionLines(description: string): string[] {
    return description.split("\n").map((line) => line.trim());
}

function emitQualifierUnion(domain: AclDomain, action: AclAction): string {
    const name = qualifierUnionName(domain, action);
    const doc = tsDoc([
        ...descriptionLines(action.description),
        "",
        ...action.qualifiers.map(
            (qualifier) =>
                `- \`${qualifier.name}\`: ${qualifier.description.replaceAll("\n", " ")}`,
        ),
    ]);
    const union = action.qualifiers.map((qualifier) => `"${qualifier.name}"`).join(" | ");
    return `${doc}\nexport type ${name} = ${union};`;
}

function emitActionToken(domain: AclDomain, action: AclAction): string {
    const name = actionTokenName(domain, action);
    const key = `${domain.name}:${action.name}`;
    const expression =
        action.qualifiers.length === 0
            ? `"${key}"`
            : `\`${key}:\${${qualifierUnionName(domain, action)}}\``;
    return `${tsDoc(descriptionLines(action.description))}\nexport type ${name} = ${expression};`;
}

function emitDomainToken(domain: AclDomain): string {
    const union = domain.actions.map((action) => actionTokenName(domain, action)).join(" | ");
    return `${tsDoc(descriptionLines(domain.description))}\nexport type ${domainTokenName(domain)} = ${union};`;
}

function emitTokenUnion(schema: AclSchema): string {
    const union = schema.domains.map((domain) => domainTokenName(domain)).join(" | ");
    return `${tsDoc(["All ACL tokens defined by this schema."])}\nexport type AclToken = ${union};`;
}

function emitActionMap(schema: AclSchema): string {
    const entries: string[] = [];
    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            const qualifier =
                action.qualifiers.length === 0 ? "never" : qualifierUnionName(domain, action);
            entries.push(`    "${domain.name}:${action.name}": ${qualifier};`);
        }
    }
    const doc = tsDoc(["Maps every action key to its qualifier union (`never` when unqualified)."]);
    return `${doc}\nexport interface AclActionMap {\n${entries.join("\n")}\n}`;
}

function emitTokenList(schema: AclSchema): string {
    const tokens: string[] = [];
    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            const key = `${domain.name}:${action.name}`;
            if (action.qualifiers.length === 0) {
                tokens.push(`    "${key}",`);
            } else {
                for (const qualifier of action.qualifiers) {
                    tokens.push(`    "${key}:${qualifier.name}",`);
                }
            }
        }
    }
    const doc = tsDoc(["Every token literal defined by this schema."]);
    return `${doc}\nexport const aclTokens = [\n${tokens.join("\n")}\n] as const;`;
}

function emitTokenGuard(): string {
    return [
        tsDoc(["Schema-level guard: whether `token` is defined by this schema."]),
        "export function isAclToken(token: string): token is AclToken {",
        "    return (aclTokens as readonly string[]).includes(token);",
        "}",
    ].join("\n");
}

function emitFactory(): string {
    return [
        tsDoc(["Creates a typed `Acl` token set for this schema."]),
        "export function createAcl(tokens: Iterable<AclToken>): Acl<AclActionMap, AclToken> {",
        "    return new Acl<AclActionMap, AclToken>(tokens);",
        "}",
    ].join("\n");
}

function emitRoles(roles: AclRole[]): string[] {
    const union = roles.map((role) => `"${role.name}"`).join(" | ");
    const roleDoc = tsDoc([
        "Roles defined by this schema.",
        "",
        ...roles.map((role) => `- \`${role.name}\`: ${role.description.replaceAll("\n", " ")}`),
    ]);
    const roleList = roles.map((role) => `    "${role.name}",`).join("\n");
    const defaults = roles.filter((role) => role.isDefault);
    const defaultList = defaults.map((role) => `    "${role.name}",`).join("\n");
    const bundles = roles
        .map((role) => {
            const tokens = role.tokens.map((token) => `"${token}"`).join(", ");
            return `    ${role.name}: [${tokens}],`;
        })
        .join("\n");
    return [
        `${roleDoc}\nexport type AclRole = ${union};`,
        `${tsDoc(["All roles in declaration order."])}\nexport const aclRoles = [\n${roleList}\n] as const;`,
        `${tsDoc(["Roles granted to fresh accounts by default."])}\nexport const aclDefaultRoles = [\n${defaultList}\n] as const;`,
        [
            tsDoc(["Schema-level guard: whether `role` is defined by this schema."]),
            "export function isAclRole(role: string): role is AclRole {",
            "    return (aclRoles as readonly string[]).includes(role);",
            "}",
        ].join("\n"),
        `${tsDoc(["The ACL tokens each role grants."])}\nconst roleTokens = {\n${bundles}\n} as const satisfies Record<AclRole, readonly AclToken[]>;`,
        [
            tsDoc([
                "Resolves role names into the union of their ACL tokens. Unknown role names",
                "are ignored so a stale or mistyped stored role cannot crash a consumer.",
            ]),
            "export function tokensForRoles(roles: Iterable<string>): AclToken[] {",
            "    const tokens = new Set<AclToken>();",
            "    for (const role of roles) {",
            "        if (!isAclRole(role)) {",
            "            continue;",
            "        }",
            "        for (const token of roleTokens[role]) {",
            "            tokens.add(token);",
            "        }",
            "    }",
            "    return [...tokens];",
            "}",
        ].join("\n"),
        [
            tsDoc(["Builds a typed `Acl` token set from role names."]),
            "export function aclForRoles(roles: Iterable<string>): Acl<AclActionMap, AclToken> {",
            "    return createAcl(tokensForRoles(roles));",
            "}",
        ].join("\n"),
    ];
}
