import hashlib

from data.lib.log import info
from data.lib.workspace.generate import GeneratorDatasource, Descriptor


def generate_hash_list(datasource: GeneratorDatasource, descriptor: Descriptor):
    generated_dir = datasource.paths.base_generate_out_path
    output_dir = datasource.config.paths.output
    hash_list_file = output_dir / "hash_list.txt"

    with hash_list_file.open("w", encoding="utf-8") as f:
        for file_path in generated_dir.rglob("*"):
            if file_path.is_file():
                relative_path = file_path.relative_to(generated_dir)
                file_size = file_path.stat().st_size
                with file_path.open("rb") as file:
                    hasher = hashlib.sha256()
                    for chunk in iter(lambda: file.read(8192), b""):
                        hasher.update(chunk)
                    file_hash = hasher.hexdigest()
                f.write(f"{relative_path.as_posix()},{file_size},{file_hash}\n")

    info(f"Generated hash list at {hash_list_file}.")
