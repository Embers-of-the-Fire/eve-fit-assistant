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
    this.acceptGraphic = true,
    this.acceptIcon = true,
    this.fallbackIcon,
  });

  final pb.Icon icon;
  final bool acceptGraphic;
  final bool acceptIcon;
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
      return fallbackIcon ?? const Image(image: ImageAssets.unknownIcon, width: 24);
    }
    return Image.file(imagePath, width: 24);
  }
}
