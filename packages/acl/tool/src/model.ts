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

/** Normalized ACL schema, preserving declaration order. */
export interface AclSchema {
    domains: AclDomain[];
}
