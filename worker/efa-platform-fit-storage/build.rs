use std::path::{Path, PathBuf};

fn workspace_root() -> PathBuf {
    let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    // CARGO_MANIFEST_DIR = <ws>/worker/efa-platform-fit-storage → workspace root is 2 parents up
    Path::new(&dir).ancestors().nth(2).unwrap().to_path_buf()
}

fn main() -> anyhow::Result<()> {
    let root = workspace_root();
    let schema_dir = root.join("data/schema");
    let engine_dir = root.join("packages/eve-fit-os");

    let schema_files = [
        "fit_request.proto",
        "fit_snapshot.proto",
        "fit.proto",
        "utils.proto",
        "platform_data.proto",
        "resource_index.proto",
        "generation_resources.proto",
    ];
    for file in schema_files {
        println!(
            "cargo::rerun-if-changed={}",
            schema_dir.join(file).display()
        );
    }
    println!(
        "cargo::rerun-if-changed={}",
        engine_dir.join("efos.proto").display()
    );

    let mut protos: Vec<PathBuf> = schema_files.iter().map(|f| schema_dir.join(f)).collect();
    protos.push(engine_dir.join("efos.proto"));

    // All map fields must be BTreeMap: HashMap iteration order is
    // nondeterministic, which would break both the canonical fit hash and
    // byte-identical snapshot determinism.
    prost_build::Config::new()
        .btree_map(["."])
        .compile_protos(&protos, &[&schema_dir, &engine_dir])?;
    Ok(())
}
