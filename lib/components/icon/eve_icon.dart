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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageService = ref.watch(imageAssetServiceProvider);
    final provider = imageService?.resolve(
      icon,
      acceptGraphic: acceptGraphic,
      acceptIcon: acceptIcon,
    );
    if (provider == null) {
      return fallbackIcon ?? Image(image: ImageAssets.unknownIcon, width: size, height: size);
    }
    if (overlayIcon == null) {
      return Image(image: provider, width: size, height: size);
    }
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        children: [
          Image(image: provider, width: size),
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
