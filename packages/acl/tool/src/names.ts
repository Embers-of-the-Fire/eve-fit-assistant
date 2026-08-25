// Single underscores only: empty segments would collapse under pascalCase(),
// letting distinct names (e.g. "read_" and "read__own") share an identifier.
const NAME_PATTERN = /^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$/;

/** Whether `name` is a valid schema name (domain, action, or qualifier). */
export function isValidName(name: string): boolean {
    return NAME_PATTERN.test(name);
}

/** Converts a snake_case schema name to PascalCase for generated type names. */
export function pascalCase(name: string): string {
    return name
        .split("_")
        .map((part) => part[0].toUpperCase() + part.slice(1))
        .join("");
}
