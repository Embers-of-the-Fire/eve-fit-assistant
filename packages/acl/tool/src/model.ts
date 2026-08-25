/** A single qualifier declared on an action. */
export interface AclQualifier {
    name: string;
    description: string;
}

/** A single action declared on a domain. */
export interface AclAction {
    name: string;
    description: string;
    qualifiers: AclQualifier[];
}

/** A permission domain grouping related actions. */
export interface AclDomain {
    name: string;
    description: string;
    actions: AclAction[];
}

/** A named role bundling schema tokens, assignable to an account. */
export interface AclRole {
    name: string;
    description: string;
    /** Token literals (`{domain}:{action}[:{qualifier}]`) this role grants. */
    tokens: string[];
    /** Whether fresh accounts start with this role. */
    isDefault: boolean;
}

/** Normalized ACL schema, preserving declaration order. */
export interface AclSchema {
    domains: AclDomain[];
    /** Declared roles; empty when the schema has no `roles` section. */
    roles: AclRole[];
}
