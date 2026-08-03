/// Platform compatibility layer for `package:file/local.dart`.
///
/// On native platforms this re-exports `package:file/local.dart` (the
/// `LocalFileSystem` implementation backed by `dart:io`). On web it exports a
/// stub whose members throw [UnsupportedError] when used.
library;

export "package:file/local.dart" if (dart.library.js_interop) "local_fs_stub.dart";
