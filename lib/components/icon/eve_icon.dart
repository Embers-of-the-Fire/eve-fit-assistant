import "dart:io";

import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/data/proto/utils.pb.dart" as pb;
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/utils/fp.dart";
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
    File? imagePath;
    if (acceptGraphic) {
      imagePath = icon.graphicId.pbOptional
          .andThen((t) => ref.watch(getGraphicPathProvider(t)))
          .tryOrElse(() => null);
    }
    if (imagePath == null && acceptIcon) {
      imagePath = icon.iconId.pbOptional
          .andThen((ic) => ref.watch(getIconPathProvider(ic)))
          .tryOrElse(() => null);
    }
    if (imagePath == null) {
      return fallbackIcon ?? Image(image: ImageAssets.unknownIcon, width: size, height: size);
    }
    if (overlayIcon == null) {
      return Image.file(imagePath, width: size, height: size);
    }
    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        children: [
          Image.file(imagePath, width: size),
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
