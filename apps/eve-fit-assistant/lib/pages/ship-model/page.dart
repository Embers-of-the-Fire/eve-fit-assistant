import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/components/model/ship_model_viewer.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Pushes the fullscreen 3D ship-model viewer for [typeId].
Future<void> showShipModelPage(BuildContext context, {required int typeId}) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (context) => ShipModelPage(typeId: typeId)));

class ShipModelPage extends ConsumerWidget {
  const ShipModelPage({required this.typeId, super.key});

  final int typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
    final locale = ref.watch(localeProvider).name;
    final name = type == null
        ? context.l10n.fallbackTypeName(typeId: typeId)
        : (watchLocalizedName(ref, id: type.typeName.id, locale: locale) ??
              context.l10n.fallbackTypeName(typeId: typeId));

    final viewerKey = GlobalKey<ShipModelViewerState>();
    return Layout(
      title: name,
      actions: [
        IconButton(
          tooltip: context.l10n.shipModelViewerResetView,
          icon: const Icon(Icons.restart_alt),
          onPressed: () => viewerKey.currentState?.resetView(),
        ),
      ],
      child: ColoredBox(
        color: Colors.black,
        child: ShipModelViewer(
          key: viewerKey,
          typeId: typeId,
          fallback: Center(child: Text(context.l10n.shipModelPageUnavailable)),
        ),
      ),
    );
  }
}
