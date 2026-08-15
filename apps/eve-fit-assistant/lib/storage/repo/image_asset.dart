import "dart:async";
import "dart:ui" as ui;

import "package:efa_proto/utils.pb.dart" as pb;
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/on_demand_blob.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/foundation.dart";
import "package:flutter/painting.dart";

@immutable
class BlobImageKey {
  const BlobImageKey(this.identHash, this.contentHash);

  final String identHash;
  final String contentHash;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlobImageKey && other.identHash == identHash && other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(identHash, contentHash);

  @override
  String toString() => "BlobImageKey($identHash, $contentHash)";
}

/// An [ImageProvider] that loads image bytes from the content-addressed blob
/// store. Keyed by [BlobImageKey] so Flutter's [ImageCache] deduplicates by
/// blob identity rather than byte-buffer identity.
///
/// The [loadImage] implementation reads bytes asynchronously from the blob
/// store (OPFS on web) and decodes them. When an [OnDemandBlobFetcher] is
/// supplied, a blob absent locally (a NON_FORCE image skipped during
/// provisioning) is downloaded transparently on first render.
class BlobImageProvider extends ImageProvider<BlobImageKey> {
  const BlobImageProvider(this.key, this._assetStore, [this._fetcher]);

  final BlobImageKey key;
  final AssetStore _assetStore;
  final OnDemandBlobFetcher? _fetcher;

  @override
  Future<BlobImageKey> obtainKey(ImageConfiguration configuration) async => key;

  @override
  ImageStreamCompleter loadImage(BlobImageKey key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _loadBytes(key).then(decode), scale: 1);

  Future<ui.ImmutableBuffer> _loadBytes(BlobImageKey key) async {
    final fetcher = _fetcher;
    final bytes = fetcher != null
        ? await fetcher.read(key.identHash, key.contentHash)
        : await _assetStore.readBlob(key.identHash, key.contentHash);
    if (bytes.isNone()) {
      throw StateError("Blob not found: ${key.identHash}/${key.contentHash}");
    }
    return ui.ImmutableBuffer.fromUint8List(bytes.toNullable()!);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BlobImageProvider && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => "BlobImageProvider($key)";
}

/// Resolves EVE image assets (icons and graphics) from the content-addressed
/// blob store via a [ResourceBlobProxy].
///
/// Returns [ImageProvider<BlobImageKey>] instances backed by
/// [BlobImageProvider], or `null` when the requested image does not exist in
/// the active resource index.
class ImageAssetService {
  const ImageAssetService(this._proxy, this._assetStore, [this._fetcher]);

  final ResourceBlobProxy _proxy;
  final AssetStore _assetStore;
  final OnDemandBlobFetcher? _fetcher;

  ImageProvider<BlobImageKey>? resolveIcon(int iconId) =>
      _resolve("resource://static/images/icons/$iconId.png");

  ImageProvider<BlobImageKey>? resolveGraphic(int graphicId) =>
      _resolve("resource://static/images/graphics/$graphicId.png");

  ImageProvider<BlobImageKey>? resolveByPath(String resourcePath) =>
      _resolve("resource://$resourcePath");

  ImageProvider<BlobImageKey>? resolve(
    pb.Icon icon, {
    bool acceptGraphic = true,
    bool acceptIcon = true,
  }) {
    if (acceptGraphic) {
      final graphicId = icon.graphicId.pbOptional;
      if (graphicId != null) {
        final provider = resolveGraphic(graphicId);
        if (provider != null) return provider;
      }
    }
    if (acceptIcon) {
      final iconId = icon.iconId.pbOptional;
      if (iconId != null) {
        return resolveIcon(iconId);
      }
    }
    return null;
  }

  ImageProvider<BlobImageKey>? _resolve(String resourceId) {
    final ident = _proxy.ident(resourceId);
    if (ident == null) return null;
    // The ResourceIndex is the source of truth for existence. A NON_FORCE
    // image skipped during provisioning is downloaded on first render via the
    // fetcher; without one, a missing blob surfaces as an image-load error
    // instead of a sync disk probe (OPFS is async).
    return BlobImageProvider(
      BlobImageKey(ident.identHash, ident.contentHash),
      _assetStore,
      _fetcher,
    );
  }
}
