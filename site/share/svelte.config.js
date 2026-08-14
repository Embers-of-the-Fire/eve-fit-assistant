import adapter from "@sveltejs/adapter-cloudflare";

/** @type {import('@sveltejs/kit').Config} */
const config = {
    compilerOptions: {
        runes: ({ filename }) =>
            filename.split(/[/\\]/).includes("node_modules") ? undefined : true,
    },
    kit: {
        adapter: adapter(),
        csp: {
            mode: "hash",
            directives: {
                "default-src": ["none"],
                "script-src": ["self"],
                "style-src": ["self"],
                "base-uri": ["none"],
                "form-action": ["none"],
            },
        },
    },
};

export default config;
