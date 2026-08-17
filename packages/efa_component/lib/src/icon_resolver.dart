import "package:efa_component/src/assets.dart";
import "package:flutter/material.dart";

/// Resolves display images for snapshot-driven surfaces.
///
/// The fit snapshot protobuf intentionally carries no image data; consumers
/// with an image registry (e.g. the app's checkout blob store or a public CDN)
/// can supply an implementation, while others get the bundled placeholder.
abstract interface class EfaIconResolver {
  /// Resolves the artwork of a game type (module, ship, charge, ...).
  ImageProvider? resolveTypeIcon(int typeId);

  /// Resolves an icon from the `utils.Icon` hint (graphic id / icon id).
  ImageProvider? resolveIconHint(int? graphicId, int? iconId);
}

/// Renders a type icon via an [EfaIconResolver], falling back to the bundled
/// placeholder. An optional overlay (e.g. meta-group marker) is stacked at the
/// top-left corner.
class EfaTypeIcon extends StatelessWidget {
  const EfaTypeIcon({
    required this.typeId,
    super.key,
    this.resolver,
    this.overlay,
    this.size = 24,
    this.overlaySize = 12,
  });

  final int typeId;
  final EfaIconResolver? resolver;
  final Widget? overlay;
  final double size;
  final double overlaySize;

  @override
  Widget build(BuildContext context) {
    final provider = resolver?.resolveTypeIcon(typeId);
    final image = provider != null
        ? Image(
            image: provider,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) =>
                efaIconImage(EfaAssets.unknownIcon, width: size, height: size),
          )
        : efaIconImage(EfaAssets.unknownIcon, width: size, height: size);
    final overlay = this.overlay;
    if (overlay == null) return image;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          image,
          Positioned(
            top: 0,
            left: 0,
            child: SizedBox(width: overlaySize, height: overlaySize, child: overlay),
          ),
        ],
      ),
    );
  }
}
