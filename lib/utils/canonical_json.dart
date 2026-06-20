import "dart:typed_data";

import "package:canonical_json/canonical_json.dart" as cj;

/// Encodes [data] as canonical JSON bytes.
///
/// Uses the ``canonical_json`` package (https://pub.dev/packages/canonical_json)
/// to produce deterministic, minimal JSON suitable for content-addressed hashing.
Uint8List canonicalJsonEncode(Object data) => Uint8List.fromList(cj.canonicalJson.encode(data));
