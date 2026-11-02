import "dart:typed_data";

import "package:efa_proto/skybox.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/constant/resource_vocabulary.g.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fpdart/fpdart.dart";

/// The sidecar schema version this client understands; anything else is
/// treated as a missing sidecar (proto2 unknown fields are simply ignored).
const int kSupportedSkyboxSidecarSchemaVersion = 1;

/// One skybox in the catalog: its canonical id (e.g. `a01`,
/// `wormhole_class_01`, `ad01_a`) and its family — the resindex directory the
/// cube was baked from (`universe` / `wormholes` / `abyssal`).
///
/// The resource index is the catalog: entries are enumerated from it, never
/// probed on disk.
class SkyboxInfo {
  const SkyboxInfo({required this.id, required this.family});

  /// Canonical skybox id (the blob stem).
  final String id;

  /// The skybox family (`universe`, `wormholes`, or `abyssal`).
  final String family;
}

/// A fetched skybox: the Radiance `.hdr` equirect bytes plus the parsed
/// [SkyboxMetadata] sidecar.
///
/// [metadata] is `null` when the sidecar is missing, undecodable, carries an
/// unsupported `schema_version`, or has a malformed `diffuse_sh` (not 27
/// floats); consumers then substitute defaults (intensity 1.0, no tint) and —
/// off the web — let the runtime compute the diffuse SH itself.
class SkyboxAsset {
  const SkyboxAsset({required this.hdrBytes, required this.metadata});

  /// The Radiance RGBE equirect (1024x512), for
  /// `EnvironmentMap.fromEquirectImageBytes`.
  final Uint8List hdrBytes;

  /// The parsed sidecar, or `null` when unusable (see above).
  final SkyboxMetadata? metadata;
}

/// Resolves baked environment skyboxes from the content-addressed blob store
/// via a [ResourceBlobProxy], mirroring `ModelAssetService`.
///
/// Skyboxes are lazy (NON_FORCE) resources: [readSkybox] downloads the blobs
/// transparently on first access when the proxy carries an
/// `OnDemandBlobFetcher`. The ResourceIndex is the source of truth for the
/// catalog, so [listSkyboxes]/[hasSkybox] need no disk probes.
class SkyboxAssetService {
  const SkyboxAssetService(this._proxy);

  final ResourceBlobProxy _proxy;

  /// The resource id of the `.hdr` equirect blob of skybox [id].
  static String skyboxHdrResourceId(String id) => "$kStaticSkyboxesResourcePrefix$id.hdr";

  /// The resource id of the `SkyboxMetadata` sidecar blob of skybox [id].
  static String skyboxSidecarResourceId(String id) => "$kStaticSkyboxesResourcePrefix$id.pb2";

  /// The skybox catalog of the active checkout, sorted by id.
  List<SkyboxInfo> listSkyboxes() {
    final skyboxes = <SkyboxInfo>[
      for (final resourceId in _proxy.resourceIdsWithPrefix(kStaticSkyboxesResourcePrefix))
        if (resourceId.endsWith(".hdr"))
          SkyboxInfo(
            id: resourceId.substring(
              kStaticSkyboxesResourcePrefix.length,
              resourceId.length - ".hdr".length,
            ),
            family: _familyOf(resourceId),
          ),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return skyboxes;
  }

  /// Whether the active checkout ships skybox [id]. The index is the catalog;
  /// only the `.hdr` blob counts — a missing sidecar degrades to consumer
  /// defaults instead of hiding the skybox.
  bool hasSkybox(String id) => _proxy.entry(skyboxHdrResourceId(id)) != null;

  /// Reads skybox [id], downloading its blobs on demand when absent locally.
  /// Returns [None] when the `.hdr` blob is not in the index or cannot be
  /// fetched; a missing/undecodable sidecar degrades to `metadata: null`.
  Future<Option<SkyboxAsset>> readSkybox(String id) async {
    final hdr = await _proxy.read(skyboxHdrResourceId(id));
    if (hdr.isNone()) return const None();
    final metadata = await _proxy
        .read(skyboxSidecarResourceId(id))
        .then((bytes) => bytes.toNullable())
        .then(_parseSidecar);
    return Some(SkyboxAsset(hdrBytes: hdr.toNullable()!, metadata: metadata));
  }

  /// Parses a sidecar blob, enforcing the supported schema version and the
  /// 27-float diffuse SH shape. Returns `null` (missing sidecar semantics)
  /// for anything unusable.
  static SkyboxMetadata? _parseSidecar(Uint8List? bytes) {
    if (bytes == null) return null;
    final SkyboxMetadata metadata;
    try {
      metadata = SkyboxMetadata.fromBuffer(bytes);
    } on Object catch (e) {
      debug("skybox sidecar undecodable: $e");
      return null;
    }
    if (metadata.schemaVersion != kSupportedSkyboxSidecarSchemaVersion) {
      debug("skybox sidecar schema_version ${metadata.schemaVersion} is unsupported");
      return null;
    }
    if (metadata.diffuseSh.isNotEmpty && metadata.diffuseSh.length != 27) {
      debug("skybox sidecar has malformed diffuse_sh (${metadata.diffuseSh.length} floats)");
      return null;
    }
    return metadata;
  }

  /// The family segment of a skybox resource id, derived from the canonical
  /// id: `wormhole_*` ids come from `wormholes`, `ad##_[abc]` ids from
  /// `abyssal`, everything else from `universe`.
  static String _familyOf(String resourceId) {
    final id = resourceId.substring(kStaticSkyboxesResourcePrefix.length);
    if (id.startsWith("wormhole_")) return "wormholes";
    if (RegExp(r"^ad\d").hasMatch(id)) return "abyssal";
    return "universe";
  }
}
