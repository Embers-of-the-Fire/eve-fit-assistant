# efa_proto

Scope: generated Dart protobuf bindings for the `.proto` sources in `data/schema/`.

- Import bindings as `package:efa_proto/<name>.pb.dart`.
- Generated files are gitignored; never check them in or edit them by hand.
- Change schemas in `data/schema/`, then regenerate from the repository root with
  `./x generate protobuf`.
- Python bindings are generated separately into `bootstrap/data/schema/`; TypeScript bindings
  live in `packages/efa_proto_ts/`.

Validation:

```sh
./x generate protobuf
```
