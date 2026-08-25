const NAME_PATTERN = /^[a-z][a-z0-9_]*$/;

/** Whether `name` is a valid schema name (domain, action, or qualifier). */
export function isValidName(name: string): boolean {
    return NAME_PATTERN.test(name);
}

/** Converts a snake_case schema name to PascalCase for generated type names. */
export function pascalCase(name: string): string {
    return name
        .split("_")
        .filter((part) => part.length > 0)
        .map((part) => part[0].toUpperCase() + part.slice(1))
        .join("");
}
