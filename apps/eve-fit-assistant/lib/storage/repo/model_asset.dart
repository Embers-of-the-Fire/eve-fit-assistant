import "dart:typed_data";

import "package:eve_fit_assistant/constant/resource_vocabulary.g.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fpdart/fpdart.dart";

/// The baked representation of a ship model GLB.
///
/// The [token] is the filename segment in the resource id
/// `resource://static/models/ships/<typeId>.<token>.glb`; it must match the
/// data pipeline's `ShipModelVariant` (bootstrap/data/workspace/generate/
/// paths.py) — rename only together with the pipeline.
enum ShipModelVariant {
  /// Full PBR texture set (baked WebP maps).
  textured("full"),

  /// Geometry with factor-only materials (no textures). A fraction of the
  /// download and GPU-memory cost of the textured variant.
  geometryOnly("base");

  const ShipModelVariant(this.token);

  /// The filename token in the resource id.
  final String token;
}

/// Resolves baked ship 3D models from the content-addressed blob store via a
/// [ResourceBlobProxy], mirroring the `ImageAssetService` pattern.
///
/// Models are lazy (NON_FORCE) resources: [readShipModel] downloads the blob
/// transparently on first access when the proxy carries an
/// `OnDemandBlobFetcher`. A type without a model (e.g. non-ship types) is
/// reported by [hasShipModel] — the ResourceIndex is the source of truth, so
/// no disk probe is needed.
class ModelAssetService {
  const ModelAssetService(this._proxy);

  final ResourceBlobProxy _proxy;

  /// The resource id of the [variant] model of ship [typeId].
  static String shipModelResourceId(int typeId, ShipModelVariant variant) =>
      "${kStaticModelsResourcePrefix}ships/$typeId.${variant.token}.glb";

  /// Whether the active checkout ships a [variant] model for [typeId].
  bool hasShipModel(int typeId, ShipModelVariant variant) =>
      _proxy.entry(shipModelResourceId(typeId, variant)) != null;

  /// Reads the GLB bytes of the [variant] model of [typeId], downloading on
  /// demand when absent locally. Returns [None] when the resource is not in
  /// the index or cannot be fetched.
  Future<Option<Uint8List>> readShipModel(int typeId, ShipModelVariant variant) =>
      _proxy.read(shipModelResourceId(typeId, variant));
}
