export default {
    compilerOptions: {
        runes: ({ filename }) =>
            filename.split(/[/\\]/).includes("node_modules") ? undefined : true,
    },
};
