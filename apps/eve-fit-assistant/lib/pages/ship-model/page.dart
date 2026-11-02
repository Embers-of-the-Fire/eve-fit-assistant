import "dart:async";

import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/components/model/ship_model_viewer.dart";
import "package:eve_fit_assistant/components/model/skybox_environment.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/skybox_asset.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Pushes the fullscreen 3D ship-model viewer for [typeId].
Future<void> showShipModelPage(BuildContext context, {required int typeId}) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (context) => ShipModelPage(typeId: typeId)));

class ShipModelPage extends ConsumerStatefulWidget {
  const ShipModelPage({required this.typeId, super.key});

  final int typeId;

  @override
  ConsumerState<ShipModelPage> createState() => _ShipModelPageState();
}

class _ShipModelPageState extends ConsumerState<ShipModelPage> {
  final GlobalKey<ShipModelViewerState> _viewerKey = GlobalKey<ShipModelViewerState>();

  /// The skybox rendered behind the model: `auto` follows the viewed ship's
  /// race default; any concrete skybox id is used verbatim. Per visit only —
  /// the selection is page state, never persisted.
  String _skyboxSelection = kShipModelSkyboxAuto;

  static const _skyboxFamilies = ["universe", "wormholes", "abyssal", "fitting"];

  @override
  Widget build(BuildContext context) {
    final typeId = widget.typeId;
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
    final locale = ref.watch(localeProvider).name;
    final name = type == null
        ? context.l10n.fallbackTypeName(typeId: typeId)
        : (watchLocalizedName(ref, id: type.typeName.id, locale: locale) ??
              context.l10n.fallbackTypeName(typeId: typeId));

    return Layout(
      title: name,
      actions: [
        IconButton(
          tooltip: context.l10n.shipModelSkyboxTitle,
          icon: const Icon(Icons.public),
          onPressed: () => unawaited(_showSkyboxPicker(context)),
        ),
        IconButton(
          tooltip: context.l10n.shipModelViewerResetView,
          icon: const Icon(Icons.restart_alt),
          onPressed: () => _viewerKey.currentState?.resetView(),
        ),
      ],
      child: ColoredBox(
        color: Colors.black,
        child: ShipModelViewer(
          key: _viewerKey,
          typeId: typeId,
          skybox: _skyboxSelection,
          fallback: Center(child: Text(context.l10n.shipModelPageUnavailable)),
        ),
      ),
    );
  }

  Future<void> _showSkyboxPicker(BuildContext context) async {
    final service = await ref.read(skyboxAssetServiceProvider.future);
    if (service == null || !context.mounted) return;
    final catalog = service.listSkyboxes();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.shipModelSkyboxTitle),
        content: SizedBox(
          width: 360,
          child: RadioGroup<String>(
            groupValue: _skyboxSelection,
            onChanged: (value) => Navigator.of(dialogContext).pop(value),
            child: ListView(
              shrinkWrap: true,
              children: [
                RadioListTile<String>(
                  value: kShipModelSkyboxAuto,
                  title: Text(dialogContext.l10n.shipModelSkyboxAuto),
                ),
                for (final family in _skyboxFamilies)
                  ..._skyboxFamilySection(dialogContext, catalog, family),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _skyboxSelection = selected);
  }

  List<Widget> _skyboxFamilySection(BuildContext context, List<SkyboxInfo> catalog, String family) {
    final skyboxes = catalog.where((skybox) => skybox.family == family).toList();
    if (skyboxes.isEmpty) return const [];
    return [
      Padding(
        padding: const .fromLTRB(16, 12, 16, 4),
        child: Text(family, style: Theme.of(context).textTheme.labelSmall),
      ),
      for (final skybox in skyboxes)
        RadioListTile<String>(value: skybox.id, title: Text(skybox.id)),
    ];
  }
}
