import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/data/proto/utils.pb.dart" as pb;
import "package:eve_fit_assistant/storage/repo/providers.dart" show imageAssetServiceProvider;
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class EveIcon extends ConsumerWidget {
  const EveIcon({
    required this.icon,
    super.key,
    this.overlayIcon,
    this.acceptGraphic = true,
    this.acceptIcon = true,
    this.size = 24,
    this.overlaySize = 12,
    this.fallbackIcon,
  });

  final pb.Icon icon;
  final pb.Icon? overlayIcon;
  final bool acceptGraphic;
  final bool acceptIcon;
  final double size;
  final double overlaySize;
  final Widget? fallbackIcon;

  Widget _fallback(double dimension) =>
      fallbackIcon ?? Image(image: ImageAssets.unknownIcon, width: dimension, height: dimension);

  /// Renders a resolved blob-store image, falling back on load failure.
  ///
  /// NON_FORCE images download lazily on first render; the fetch can fail
  /// (offline, CORS, evicted browser storage) and must not leave a broken
  /// image slot.
  Widget _resolvedImage(ImageProvider<Object> provider, double width, double? height) => Image(
    image: provider,
    width: width,
    height: height,
    errorBuilder: (context, error, stackTrace) => _fallback(width),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Async provider: null while the active ResourceIndex loads; icons fall
    // back briefly until the image service is available.
    final imageService = ref.watch(imageAssetServiceProvider).value;
    final provider = imageService?.resolve(
      icon,
      acceptGraphic: acceptGraphic,
      acceptIcon: acceptIcon,
    );
    if (provider == null) {
      return _fallback(size);
    }
    if (overlayIcon == null) {
      return _resolvedImage(provider, size, size);
    }
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        children: [
          _resolvedImage(provider, size, null),
          Positioned(
            top: 0,
            left: 0,
            child: EveIcon(
              icon: overlayIcon!,
              acceptGraphic: acceptGraphic,
              acceptIcon: acceptIcon,
              size: overlaySize,
              fallbackIcon: const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
