import type { AclAction, AclDomain, AclSchema } from "./model.ts";
import { pascalCase } from "./names.ts";

const HEADER = "// GENERATED CODE - DO NOT EDIT BY HAND. Regenerate with `acl-codegen`.";

/** Emits Dart bindings for a validated ACL schema. */
export function emitDart(schema: AclSchema): string {
    const chunks: string[] = [HEADER, 'import "package:acl/acl.dart";'];

    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            if (action.qualifiers.length > 0) {
                chunks.push(emitQualifierEnum(domain, action));
            }
        }
    }

    chunks.push(emitTokenBase());

    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            chunks.push(emitTokenClass(domain, action));
        }
    }

    chunks.push(emitParser(schema));
    chunks.push(emitQueries(schema));

    return `${chunks.join("\n\n")}\n`;
}

function qualifierEnumName(domain: AclDomain, action: AclAction): string {
    return `${pascalCase(domain.name)}${pascalCase(action.name)}Qualifier`;
}

function tokenClassName(domain: AclDomain, action: AclAction): string {
    return `${pascalCase(domain.name)}${pascalCase(action.name)}`;
}

function queryName(domain: AclDomain, action: AclAction): string {
    return `can${pascalCase(domain.name)}${pascalCase(action.name)}`;
}

function dartDoc(lines: string[]): string {
    return lines.map((line) => (line === "" ? "///" : `/// ${line}`)).join("\n");
}

function descriptionLines(description: string): string[] {
    return description.split("\n").map((line) => line.trim());
}

function indent(text: string): string {
    return `  ${text.replaceAll("\n", "\n  ")}`;
}

function emitQualifierEnum(domain: AclDomain, action: AclAction): string {
    const name = qualifierEnumName(domain, action);
    const doc = dartDoc([`Qualifiers for \`${domain.name}:${action.name}\`.`]);
    const values = action.qualifiers
        .map(
            (qualifier) =>
                `${indent(dartDoc(descriptionLines(qualifier.description)))}\n  ${qualifier.name},`,
        )
        .join("\n\n");
    return `${doc}\nenum ${name} {\n${values}\n}`;
}

function emitTokenBase(): string {
    return [
        dartDoc(["Base type for all ACL tokens defined by this schema."]),
        "sealed class AclToken {",
        "  const AclToken();",
        "",
        indent(
            dartDoc(["Encodes this token into its `{domain}:{action}[:{qualifier}]` string form."]),
        ),
        "  String encode();",
        "}",
    ].join("\n");
}

function emitTokenClass(domain: AclDomain, action: AclAction): string {
    const name = tokenClassName(domain, action);
    const key = `${domain.name}:${action.name}`;
    const doc = dartDoc(descriptionLines(action.description));
    if (action.qualifiers.length === 0) {
        return [
            doc,
            `final class ${name} extends AclToken {`,
            `  const ${name}();`,
            "",
            "  @override",
            `  String encode() => "${key}";`,
            "}",
        ].join("\n");
    }
    return [
        doc,
        `final class ${name} extends AclToken {`,
        `  const ${name}(this.qualifier);`,
        "",
        indent(dartDoc(["The qualifier narrowing this action."])),
        `  final ${qualifierEnumName(domain, action)} qualifier;`,
        "",
        "  @override",
        `  String encode() => "${key}:\${qualifier.name}";`,
        "}",
    ].join("\n");
}

function emitParser(schema: AclSchema): string {
    const arms: string[] = [];
    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            const className = tokenClassName(domain, action);
            const head = `"${domain.name}", "${action.name}"`;
            if (action.qualifiers.length === 0) {
                arms.push(`  [${head}] => const ${className}(),`);
            } else {
                const qualifierArms = action.qualifiers
                    .map(
                        (qualifier) =>
                            `    "${qualifier.name}" => const ${className}(${qualifierEnumName(domain, action)}.${qualifier.name}),`,
                    )
                    .join("\n");
                arms.push(
                    [
                        `  [${head}, final qualifier] => switch (qualifier) {`,
                        qualifierArms,
                        "    _ => null,",
                        "  },",
                    ].join("\n"),
                );
            }
        }
    }
    return [
        dartDoc([
            "Parses [token] into a schema-defined [AclToken], or returns `null` when",
            "the token is not defined by this schema.",
        ]),
        'AclToken? parseAclToken(String token) => switch (token.split(":")) {',
        arms.join("\n"),
        "  _ => null,",
        "};",
    ].join("\n");
}

function emitQueries(schema: AclSchema): string {
    const members: string[] = [
        `${indent(dartDoc(["Whether this set contains [token] exactly, qualifier included."]))}\n  bool hasToken(AclToken token) => has(token.encode());`,
    ];
    for (const domain of schema.domains) {
        for (const action of domain.actions) {
            const key = `${domain.name}:${action.name}`;
            const doc = indent(dartDoc(descriptionLines(action.description)));
            if (action.qualifiers.length === 0) {
                members.push(
                    `${doc}\n  bool ${queryName(domain, action)}() => can("${key}") as bool;`,
                );
            } else {
                const enumName = qualifierEnumName(domain, action);
                members.push(
                    [
                        doc,
                        `  Set<${enumName}>? ${queryName(domain, action)}() {`,
                        `    final matched = can("${key}");`,
                        "    if (matched is! Set<String>) {",
                        "      return null;",
                        "    }",
                        `    return {for (final qualifier in matched) ${enumName}.values.byName(qualifier)};`,
                        "  }",
                    ].join("\n"),
                );
            }
        }
    }
    return [
        dartDoc(["Typed queries over an [Acl] token set for this schema."]),
        "extension AclTokenQueries on Acl {",
        members.join("\n\n"),
        "}",
    ].join("\n");
}
