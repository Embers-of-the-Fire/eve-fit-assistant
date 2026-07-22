use std::path::{Path, PathBuf};

fn workspace_root() -> PathBuf {
    let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    // CARGO_MANIFEST_DIR = <ws>/pkgs/worker/release → workspace root is 3 parents up
    Path::new(&dir).ancestors().nth(3).unwrap().to_path_buf()
}

fn main() -> anyhow::Result<()> {
    let schema_dir = workspace_root().join("data/schema");

    println!(
        "cargo::rerun-if-changed={}",
        schema_dir.join("release_index.proto").display()
    );
    println!(
        "cargo::rerun-if-changed={}",
        schema_dir.join("generation_pointer.proto").display()
    );

    prost_build::Config::new().compile_protos(
        &["release_index.proto", "generation_pointer.proto"],
        &[&schema_dir],
    )?;
    Ok(())
}
