# Data for EVE Fit Assistant

## Environment variable

### Server

`SERVER`: Possible value: `tq` or `se`.

## External dataset

| Data Identifier    | Recommended Save Path                               | Download URL                                     |
|--------------------|-----------------------------------------------------|--------------------------------------------------|
| FSD                | `./fsd`                                             | See `Embers-of-the-Fire/eve-multitools-archive`  |
| FSD Localization   | `./fsd-localization/localization_fsd_en-us.pickle`  | See `Embers-of-the-Fire/eve-multitools-archive`  |
| `resfileindex.txt` | `.`                                                 | `<path-to-eve-client>\tq\resfileindex.txt`       |

### Patches

Some of the data cannot be unpacked even from the game client.
So we have to manually create and record them.

Those data is stored in the `./patches` directory and is preserved by the VCS.

There's no definite rule about how each patch file means and operates,
but some patches do have a documentation file or generator script.

### Cache directory

- `index-cache`:
  This dir contains files downloaded from the official website.
  The download URLs are extracted from `resfileindex.txt`.
- `cache`:
  This dir stores data to be bundled into the app.

## Generate the bundle

> For all shell examples below, we assume that you are in `eve-fit-assistant/data`.

The bundle generation has mainly four stages:

### 1. Compile the protobuf

By default, all protobuf compile outputs are checked-in and should be up-to-date.

To generate the protobuf code, run:

```powershell
.\compile.ps1
```

<details><summary>Manually</summary>

1.  Clear pre-compiled files:

    ```bash
    rm -rf ./convert/*_pb2.py
    ```
2.  Compile the protobuf:

    ```bash
    protoc -I./schema --python_out=./convert --dart_out=../lib/storage/proto ./schema/*.proto
    ```

</details>


### 2. Convert the FSD and ResFile

```powershell
.\convert.ps1
```

<details><summary>Manually</summary>

1.  Convert app-used data:

    ```bash
    uv run ./convert/run.py ./fsd ./resfileindex.txt ./out ./index-cache
    ```
2.  Convert native data:

    ```bash
    cd ../rust/lib/eve-fit-os/
    uv sync # sync the environment
    uv run -m data.convert ../../../data/fsd ./data/patches ./data/out
    ```

</details>

### 3. Generate the bundle

If this is your first time to run the script, download full data first.

```powershell
.\bundle.ps1 -Download
```

To skip downloading (mainly static images), run:

```powershell
.\bundle.ps1
```

**Additional switch:** `-ClearCache`: clear the cache dir before executing commands.

And finally, to generate release version information, run:

```powershell
.\codegen.ps1
```

<details><summary>Manually</summary>

1.  Create a version timestamp:
    
    ```powershell
    New-Item -ItemType File -Force -Path ./cache/version
    Set-Content -Path ./cache/version -Value (Get-Data -UFormat %s) -Force
    ```
    
    **Hint:** The timestamp is in seconds since the Unix epoch.

    This will write the current timestamp to file `./cache/version`
2.  Copy protobuf files:

    ```bash
    cp ./out/pb2/*.pb ./cache/
    ```
3.  Execute extra python scripts:

    ```bash
    uv run ./bundle/extra.py ./fsd ./images ./resfileindex.txt --download
    ```
    
    **Note:** omit `--download` to skip downloading files.
4.  Copy native output:

    ```bash
    mkdir ./cache/native
    # We only uses the following 4 files at runtime
    cp ../rust/lib/eve-fit-os/data/out/pb2/dogmaAttributes.pb2 ./cache/native
    cp ../rust/lib/eve-fit-os/data/out/pb2/dogmaEffects.pb2 ./cache/native
    cp ../rust/lib/eve-fit-os/data/out/pb2/typeDogma.pb2 ./cache/native
    cp ../rust/lib/eve-fit-os/data/out/pb2/types.pb2 ./cache/native 
    ```
5.  Create the tarball:
    ```bash
    tar -czf ./storage.tar.gz -C ./cache .
    ```

</details>
