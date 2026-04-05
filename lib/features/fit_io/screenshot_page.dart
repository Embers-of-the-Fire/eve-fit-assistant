import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/native.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

class FitScreenshotPage extends ConsumerStatefulWidget {
  const FitScreenshotPage({required this.fit, super.key, this.emulated});

  final FitStorage fit;
  final native.Ship? emulated;

  @override
  ConsumerState<FitScreenshotPage> createState() => _FitScreenshotPageState();
}

class _FitScreenshotPageState extends ConsumerState<FitScreenshotPage> {
  final GlobalKey _captureKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _handleSave,
                icon: const Icon(Icons.download_outlined),
                label: Text(context.l10n.fitScreenshotSave),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _handleShare,
                icon: const Icon(Icons.share_outlined),
                label: Text(context.l10n.fitScreenshotShare),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RepaintBoundary(
                key: _captureKey,
                child: _FitScreenshotCard(fit: widget.fit, emulated: widget.emulated),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _handleSave() async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(
        pngBytes,
        directoryPath: PathProvider.downloadsPath ?? PathProvider.documentsPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.fitScreenshotSaved(path: file.path))));
    });
  }

  Future<void> _handleShare() async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(pngBytes, directoryPath: PathProvider.tempPath);
      await Share.shareXFiles([XFile(file.path)], subject: widget.fit.metadata.name);
    });
  }

  Future<void> _runCaptureAction(Future<void> Function(Uint8List pngBytes) action) async {
    setState(() => _busy = true);
    try {
      final pngBytes = await _capturePng();
      if (pngBytes == null) return;
      await action(pngBytes);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<Uint8List?> _capturePng() async {
    final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(1.5, 3.0);
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<File> _writePng(Uint8List pngBytes, {required String directoryPath}) async {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final safeName = widget.fit.metadata.name.replaceAll(RegExp("[^A-Za-z0-9._-]+"), "_");
    final fileName =
        "${safeName.isEmpty ? "fit" : safeName}_${DateTime.now().millisecondsSinceEpoch}.png";
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }
}

class _FitScreenshotCard extends StatelessWidget {
  const _FitScreenshotCard({required this.fit, required this.emulated});

  final FitStorage fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context) => Container(
    width: _ScreenshotTabPanel.width * 4 + 36,
    color: context.theme.scaffoldBackgroundColor,
    padding: const EdgeInsets.all(12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenshotTabPanel(
          title: context.l10n.frontPageTitleCharacter,
          child: _CharacterSummary(fit: fit),
        ),
        const SizedBox(width: 12),
        _ScreenshotTabPanel(
          title: context.l10n.fitScreenshotEquipment,
          child: _EquipmentSummary(fit: fit),
        ),
        const SizedBox(width: 12),
        _ScreenshotTabPanel(
          title: context.l10n.fitScreenshotStats,
          child: _AttributeSummary(fit: fit, emulated: emulated),
        ),
        const SizedBox(width: 12),
        _ScreenshotTabPanel(
          title: context.l10n.fitScreenshotMinions,
          child: _MinionSummary(fit: fit, emulated: emulated),
        ),
      ],
    ),
  );
}

class _ScreenshotTabPanel extends StatelessWidget {
  const _ScreenshotTabPanel({required this.title, required this.child});

  static const width = 360.0;

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surface,
      border: Border.all(color: context.theme.colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title, style: context.theme.textTheme.titleMedium),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ],
    ),
  );
}

class _CharacterSummary extends StatelessWidget {
  const _CharacterSummary({required this.fit});

  final FitStorage fit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(fit.metadata.name, style: context.theme.textTheme.titleMedium),
      const SizedBox(height: 4),
      if (fit.metadata.description.trim().isNotEmpty) ...[
        Text(
          fit.metadata.description,
          style: context.theme.textTheme.bodySmall?.copyWith(
            color: context.theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
      _SectionLabel(title: context.l10n.implantSlot),
      const SizedBox(height: 8),
      if (fit.body.implants.isEmpty) Text(context.l10n.fitScreenshotEmpty),
      ...fit.body.implants.indexed.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SimpleTypeRow(
            title: "${context.l10n.implantSlot} ${entry.$1 + 1}",
            typeId: _resolveTypeId(fit, entry.$2.itemId),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionLabel(title: context.l10n.boosterSlot),
      const SizedBox(height: 8),
      if (fit.body.boosters.isEmpty) Text(context.l10n.fitScreenshotEmpty),
      ...fit.body.boosters.map(
        (booster) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SimpleTypeRow(
            title: "${context.l10n.boosterSlot} ${booster.index}",
            typeId: _resolveTypeId(fit, booster.itemId),
          ),
        ),
      ),
    ],
  );
}

class _EquipmentSummary extends StatelessWidget {
  const _EquipmentSummary({required this.fit});

  final FitStorage fit;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      fit.body.slots.tacticalMode.match(
        () => const SizedBox.shrink(),
        (value) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SimpleTypeRow(title: context.l10n.tacticalMode, typeId: value),
        ),
      ),
      _SlotList(title: context.l10n.highSlot, slots: fit.body.slots.high, fit: fit),
      _SlotList(title: context.l10n.midSlot, slots: fit.body.slots.medium, fit: fit),
      _SlotList(title: context.l10n.lowSlot, slots: fit.body.slots.low, fit: fit),
      _SlotList(title: context.l10n.rigSlot, slots: fit.body.slots.rig, fit: fit),
      _SlotList(title: context.l10n.subsystemSlot, slots: fit.body.slots.subsystem, fit: fit),
      _SlotList(title: context.l10n.serviceSlot, slots: fit.body.slots.service, fit: fit),
    ],
  );
}

class _AttributeSummary extends StatelessWidget {
  const _AttributeSummary({required this.fit, required this.emulated});

  final FitStorage fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SimpleTypeRow(typeId: fit.body.shipTypeId),
      const SizedBox(height: 12),
      _SectionLabel(title: context.l10n.fitScreenshotDamageProfile),
      const SizedBox(height: 8),
      Text(
        "EM ${(fit.body.damageProfile.em * 100).round()}% / "
        "TH ${(fit.body.damageProfile.thermal * 100).round()}% / "
        "KI ${(fit.body.damageProfile.kinetic * 100).round()}% / "
        "EX ${(fit.body.damageProfile.explosive * 100).round()}%",
      ),
      const SizedBox(height: 12),
      _SectionLabel(title: context.l10n.fitScreenshotStats),
      const SizedBox(height: 8),
      _StatSummary(emulated: emulated),
    ],
  );
}

class _MinionSummary extends StatelessWidget {
  const _MinionSummary({required this.fit, required this.emulated});

  final FitStorage fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel(title: context.l10n.drone),
      const SizedBox(height: 8),
      if (fit.body.drones.isEmpty) Text(context.l10n.fitScreenshotEmpty),
      ...fit.body.drones.map(
        (drone) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SimpleTypeRow(
            title: "${context.l10n.drone} x${drone.quantity}",
            typeId: _resolveTypeId(fit, drone.itemId),
          ),
        ),
      ),
      const SizedBox(height: 12),
      _SectionLabel(title: context.l10n.fighter),
      const SizedBox(height: 8),
      if (fit.body.fighters.isEmpty) Text(context.l10n.fitScreenshotEmpty),
      ...fit.body.fighters.map(
        (fighter) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SimpleTypeRow(
            title: "${context.l10n.fighter} x${fighter.quantity}",
            typeId: _resolveTypeId(fit, fighter.itemId),
          ),
        ),
      ),
      if (emulated != null) ...[
        const SizedBox(height: 12),
        _SectionLabel(title: context.l10n.fitScreenshotFighterCapacity),
        const SizedBox(height: 8),
        Text(
          "H ${emulated!.hull.getAttribute(EveConstAttrID.fighterHeavySlots).round()} / "
          "L ${emulated!.hull.getAttribute(EveConstAttrID.fighterLightSlots).round()} / "
          "S ${emulated!.hull.getAttribute(EveConstAttrID.fighterSupportSlots).round()} / "
          "x ${fit.body.fighters.length}/${emulated!.hull.getAttribute(EveConstAttrID.fighterTubes).round()}",
        ),
      ],
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: context.theme.textTheme.titleSmall);
}

class _StatSummary extends StatelessWidget {
  const _StatSummary({required this.emulated});

  final native.Ship? emulated;

  @override
  Widget build(BuildContext context) {
    final hull = emulated?.hull;
    if (hull == null) {
      return Text(context.l10n.fitScreenshotStatsUnavailable);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatLine(
          label: context.l10n.fitScreenshotShieldHp,
          value: hull.getAttribute(EveConstAttrID.shieldCapacity).toStringAsFixed(1),
        ),
        _StatLine(
          label: context.l10n.fitScreenshotArmorHp,
          value: hull.getAttribute(EveConstAttrID.armorHP).toStringAsFixed(1),
        ),
        _StatLine(
          label: context.l10n.fitScreenshotHullHp,
          value: hull.getAttribute(EveConstAttrID.hp).toStringAsFixed(1),
        ),
        _StatLine(
          label: context.l10n.fitScreenshotCapacitor,
          value: hull.getAttribute(EveConstAttrID.capacitorCapacity).toStringAsFixed(1),
        ),
        _StatLine(
          label: context.l10n.fitScreenshotDroneBandwidth,
          value: hull.getAttribute(EveConstAttrID.droneBandwidth).toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: context.theme.textTheme.titleSmall),
      ],
    ),
  );
}

class _SlotList extends StatelessWidget {
  const _SlotList({required this.title, required this.slots, required this.fit});

  final String title;
  final IList<Option<FitModuleItem>> slots;
  final FitStorage fit;

  @override
  Widget build(BuildContext context) {
    final nonEmpty = slots.filterNone();
    if (nonEmpty.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(title: title),
          const SizedBox(height: 8),
          ...nonEmpty.map(
            (slot) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SlotRow(fit: fit, slot: slot),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.fit, required this.slot});

  final FitStorage fit;
  final FitModuleItem slot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SimpleTypeRow(typeId: _resolveTypeId(fit, slot.itemId)),
      slot.charge.match(
        () => const SizedBox.shrink(),
        (charge) => Padding(
          padding: const EdgeInsets.only(left: 16, top: 4),
          child: _SimpleTypeRow(typeId: charge.typeId, title: context.l10n.charge),
        ),
      ),
    ],
  );
}

class _SimpleTypeRow extends ConsumerWidget {
  const _SimpleTypeRow({required this.typeId, this.title});

  final int? typeId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (typeId == null) {
      return Text(title ?? context.l10n.fitScreenshotEmpty);
    }

    final type = ref.watch(bundleCollectionGetTypeProvider(typeId!));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (type?.icon case final icon?) ...[EveIcon(icon: icon), const SizedBox(width: 8)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              TypeNameText(typeId: typeId!),
            ],
          ),
        ),
      ],
    );
  }
}

int? _resolveTypeId(FitStorage fit, FitStorageItemId itemId) => itemId.when(
  item: (id) => id,
  dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
);
