# EFA Data Generator

This folder contains scripts and resources to generate
synthetic data for the application.

## Resource Dependencies

The data generation process relies on the following resources:
- **FSD Binary (Exported)**:
  FSD contains static data files used by the game and our application.
  We use an exported version of the FSD binary to extract these files,
  since the generator itself is not capable of reading the binary format,
  and the reader is extracted from the game, which means it's not available
  in the repository or CI/CD and is not cross-platform.
  
  This project recommend to use
  [EVE FSD Dumper](https://github.com/Embers-of-the-Fire/EVE-FSD-Dumper)
  to extract the necessary files from the FSD binary.
  An extracted version of the FSD binary is included in
  [EVE Multitools Archive](https://github.com/Embers-of-the-Fire/EVE-Multitools-Archive)
  which is currently not publicly available, but can be requested from the maintainer.

  > **Note**: We use msgpack to decode the extracted files, which is more efficient
  > and could preserve integer keys. Some exporters may export to JSON instead,
  > but the dumper listed above supports msgpack natively.
- **Resource Index**:
  The resource index, aka `resfileindex.txt`, describes all resources used by the game.
  A copy of it could be got from the game client, but it's also included in the archive
  repository listed above.
- **Application Index**:
  The application index, `index_<server name>.txt`, describes all resources forming the
  game executable, including dynamic libraries and other resources.
  This file is hosted just like the resource index.
- **Start Configuration**:
  We only uses the configuration for EVE on Windows, which is `start.ini`.
  This file contains multiple settings and metadata about the game client.
  It can be fetched from either the game client or the archive repository.

The dependencies is generally recommended to be placed like this:
```text
- /resources/<server name>/
  - start.ini
  - index_application.txt # the index_<server name>.txt file renamed
  - resfileindex.txt
  - fsd/
    - xxx.msgpack # the extracted FSD files
```

## Resource Format

The resource files are generally in protobuf format.
The protobuf definitions are included in the `schema` folder.

Basically, all static data are stored collectively in a single protobuf message,
see [`collections.proto`](./schema/collections.proto) for details.

And, the localizations are stored in separate protobuf messages per language,
see [`localizations.proto`](./schema/localizations.proto) for details.

The converted output shall be a zip archive containing:
```text
- /
  - descriptor.json             # metadata about the generation
  - static/
    - native/                   # native data, used by eve-fit-os
      - *.pb2                   # native static data collection
    - collections.pb2           # static data collection
    - images/
      - icons/                  # icon images
        - <icon_id>.png         # icon image file
      - graphics/               # other graphics
        - <graphic_id>.png      # graphic image file
        - <graphic_id>_bp.png   # blueprint image file
        - <graphic_id>_bpc.png  # high quality image file
  - localization/
    - localization_<lang>.pb2   # for each supported language
```

## Generate Routine

The data generation process contains the following steps:
1. **Preparation**:  
   Load the resource index, application index, and start configuration.  
   Verify the existence of the extracted FSD files.  
   Create necessary output directories.  
   Generate descriptor file.
2. **Static Data Extraction**:  
   Extract the static data files from the extracted FSD files and/or the resource files.  
   Parse the files and merge them into a single protobuf message.
3. **Native Data Conversion**:  
   Convert the native static data used by `eve-fit-os`.
4. **Localization Extraction**:  
   Extract the localization files from the extracted FSD files and/or the resource files.  
   Parse the files and merge them into separate protobuf messages per language.
5. **Image Extraction**:  
   Extract the icon and graphic images from the extracted FSD files and/or the resource files.  
   Save them into the output directory.
6. **Packaging**:  
   Save all generated files into a zip archive.
