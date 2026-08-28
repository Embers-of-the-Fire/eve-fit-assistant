import "package:efa_component/efa_component.dart" show EfaIconResolver;
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/image_asset.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter/painting.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "efa_icon_resolver.g.dart";

/// Bridges the app's data repository (type metadata) and content-addressed
/// image service into an [EfaIconResolver] for the shared presentational
/// widgets (`efa_component`, `efa_fit_snapshot`). Resolution fails soft: a
/// missing collection, unknown type, or absent image yields null and the
/// widget falls back to its bundled placeholder.
class AppEfaIconResolver implements EfaIconResolver {
  const AppEfaIconResolver(this._collection, this._images);

  final RepoCollectionService? _collection;
  final ImageAssetService? _images;

  @override
  ImageProvider? resolveTypeIcon(int typeId) {
    final path = _collection?.getIconPath(typeId, 64) ?? "";
    if (path.isEmpty) return null;
    return _images?.resolveByPath(path);
  }

  @override
  ImageProvider? resolveIconHint(int? graphicId, int? iconId) {
    if (iconId != null) return _images?.resolveIcon(iconId);
    if (graphicId != null) return _images?.resolveGraphic(graphicId);
    return null;
  }
}

/// The app-wide [EfaIconResolver], rebuilt when the active collection or the
/// image service changes.
@riverpod
EfaIconResolver appEfaIconResolver(Ref ref) => AppEfaIconResolver(
  ref.watch(repoCollectionProvider),
  ref.watch(imageAssetServiceProvider).value,
);
