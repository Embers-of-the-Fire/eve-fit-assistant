part of "page.dart";

class FitScreenshotPage extends ConsumerStatefulWidget {
  const FitScreenshotPage({required this.fitId, super.key});

  final String fitId;

  @override
  ConsumerState<FitScreenshotPage> createState() => _FitScreenshotPageState();
}

class _FitScreenshotPageState extends ConsumerState<FitScreenshotPage> {
  final GlobalKey _captureKey = GlobalKey();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final fitState = ref.watch(fitProvider(widget.fitId));
    final emulatorState = ref.watch(fitEmulatorServiceProvider(widget.fitId));
    final emulated = emulatorState.when(
      notInitialized: () => null,
      emulating: (previous) => null,
      error: (message, previous) => null,
      emulated: (output) => output,
    );
    final shipInfo = fitState.isInitialized
        ? ref.watch(repoCollectionProvider.select((c) => c?.getShip(fitState.fit.body.shipTypeId)))
        : null;

    if (fitState.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
        body: _FitPageErrorState(
          icon: Icons.error_outline,
          title: context.l10n.fitPageUnavailableTitle,
          message: localizeFitErrorMessage(
            context.l10n,
            fitState.errorMessageKey ?? FitErrorMessageKey.fitLoadFailed,
          ),
          actions: [
            FilledButton.icon(
              onPressed: ref.read(fitProvider(widget.fitId).notifier).reload,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.fitPageRetryAction),
            ),
          ],
        ),
      );
    }

    if (emulatorState.hasError) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
        body: _FitPageErrorState(
          icon: Icons.calculate_outlined,
          title: context.l10n.fitPageStatsUnavailableTitle,
          message: localizeFitErrorMessage(
            context.l10n,
            emulatorState.errorMessageKey ?? FitErrorMessageKey.fitStatsUnavailable,
          ),
          actions: [
            FilledButton.icon(
              onPressed: ref.read(fitEmulatorServiceProvider(widget.fitId).notifier).retry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.fitPageRetryAction),
            ),
          ],
        ),
      );
    }

    if (!fitState.isInitialized || emulated == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
        body: const Center(
          child: SizedBox(height: 40, child: LoadingIndicator(indicatorType: Indicator.lineScale)),
        ),
      );
    }

    if (shipInfo == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.fitScreenshotPageTitle)),
        body: _FitPageErrorState(
          icon: Icons.directions_boat_filled_outlined,
          title: context.l10n.fitPageUnavailableTitle,
          message: context.l10n.fitPageShipUnavailableMessage,
          details: "typeId=${fitState.fit.body.shipTypeId}",
        ),
      );
    }

    final fitContext = FitContext(
      fitId: widget.fitId,
      fit: fitState.fit,
      ship: shipInfo,
      emulated: emulated,
      fitWrapper: FitWrapper(
        wrapped: ref.read(fitProvider(widget.fitId).notifier),
        fitId: widget.fitId,
        ref: ref,
      ),
    );

    return Scaffold(
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
                  onPressed: _busy ? null : () => _handleSave(fitContext),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(context.l10n.fitScreenshotSave),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _handleShare(fitContext),
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
                  child: _FitScreenshotSurface(fitContext: fitContext),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(FitContext fitContext) async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(
        pngBytes,
        fitContext: fitContext,
        directoryPath: PathProvider.downloadsPath ?? PathProvider.documentsPath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.fitScreenshotSaved(path: file.path))));
    });
  }

  Future<void> _handleShare(FitContext fitContext) async {
    await _runCaptureAction((pngBytes) async {
      final file = await _writePng(
        pngBytes,
        fitContext: fitContext,
        directoryPath: PathProvider.tempPath,
      );
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: fitContext.fit.metadata.name),
      );
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

  Future<File> _writePng(
    Uint8List pngBytes, {
    required String directoryPath,
    required FitContext fitContext,
  }) async {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }

    final safeName = fitContext.fit.metadata.name.replaceAll(RegExp("[^A-Za-z0-9._-]+"), "_");
    final fileName =
        "${safeName.isEmpty ? "fit" : safeName}_${DateTime.now().millisecondsSinceEpoch}.png";
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }
}

class _FitScreenshotSurface extends StatelessWidget {
  const _FitScreenshotSurface({required this.fitContext});

  static const _columnWidth = 420.0;

  final FitContext fitContext;

  @override
  Widget build(BuildContext context) => Container(
    color: context.theme.scaffoldBackgroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScreenshotColumn(
          width: _columnWidth,
          child: _ScreenshotCharacterColumn(fitContext: fitContext),
        ),
        const SizedBox(width: 12),
        _ScreenshotColumn(
          width: _columnWidth,
          child: _ScreenshotEquipmentColumn(fitContext: fitContext),
        ),
        const SizedBox(width: 12),
        _ScreenshotColumn(
          width: _columnWidth,
          child: _ScreenshotAttributeColumn(fitContext: fitContext),
        ),
      ],
    ),
  );
}

class _ScreenshotColumn extends StatelessWidget {
  const _ScreenshotColumn({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surface,
      border: Border.all(color: context.theme.colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child),
  );
}

class _ScreenshotCharacterColumn extends ConsumerWidget {
  const _ScreenshotCharacterColumn({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final implantAssignments = _buildImplantAssignments(fit, ref);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EquipmentHeader(
          title: context.l10n.implantSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.implant),
          interactiveIssueIndicator: false,
        ),
        for (int slotId = 0; slotId < _maxImplantSlots; slotId++)
          if (implantAssignments.containsKey(slotId))
            _ImplantRow(
              fitContext: fitContext,
              slotId: slotId,
              storageIndex: implantAssignments[slotId]!,
              interactionOptions: FitInteractionOptions.screenshot,
            )
          else
            _EmptyImplantRow(
              fitContext: fitContext,
              slotId: slotId,
              interactionOptions: FitInteractionOptions.screenshot,
            ),
        _EquipmentHeader(
          title: context.l10n.boosterSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.booster),
          interactiveIssueIndicator: false,
        ),
        if (fit.body.boosters.isEmpty)
          ListTile(title: Text(context.l10n.fitSlotEmpty(slotName: context.l10n.boosterSlot))),
        for (final booster in fit.body.boosters)
          _BoosterRow(
            fitContext: fitContext,
            slotId: booster.index,
            interactionOptions: FitInteractionOptions.screenshot,
          ),
      ],
    );
  }
}

class _ScreenshotEquipmentColumn extends ConsumerWidget {
  const _ScreenshotEquipmentColumn({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final subsystemSlotCount = fitContext.ship.subsystemSlots.clamp(
      0,
      fit.body.slots.subsystem.length,
    );

    final droneBayUsed =
        fitContext.emulated?.hull.getAttribute(EveConstExtendedAttrID.droneCapacityLoad).round() ??
        0;
    final droneBayCapacity =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.droneCapacity).round() ?? 0;
    final fighterHangarUsed =
        fitContext.emulated?.hull
            .getAttribute(EveConstExtendedAttrID.fighterCapacityLoad)
            .round() ??
        0;
    final fighterHangarCapacity =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.fighterCapacity).round() ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...fit.body.slots.tacticalMode.match(
          () => const <Widget>[],
          (mode) => [
            _EquipmentHeader(
              title: context.l10n.tacticalMode,
              issues: _collectFitIssuesForSection(
                context,
                ref,
                fitContext,
                _FitIssueSection.tacticalMode,
              ),
              interactiveIssueIndicator: false,
            ),
            _AnySlotRow(
              fitContext: fitContext,
              slotIdent: const SlotIdentifier.tacticalMode(),
              slotInfo: SlotInfo.item(
                state: FitItemState.active,
                type: const native.OutSlotType.tacticalMode(),
                index: 0,
                slot: FitModuleItem(
                  charge: const Option.none(),
                  state: FitItemState.active,
                  itemId: FitStorageItemId.item(id: mode),
                ),
              ),
              interactionOptions: FitInteractionOptions.screenshot,
            ),
          ],
        ),
        _EquipmentHeader(
          title: context.l10n.highSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.high),
          rightInfo: [_HighSlotHardpointInfo(fitContext: fitContext)],
          interactiveIssueIndicator: false,
        ),
        ...fit.body.slots.high.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.high(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.high(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        ),
        _EquipmentHeader(
          title: context.l10n.midSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.medium),
          interactiveIssueIndicator: false,
        ),
        ...fit.body.slots.medium.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.medium(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.medium(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        ),
        _EquipmentHeader(
          title: context.l10n.lowSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.low),
          interactiveIssueIndicator: false,
        ),
        ...fit.body.slots.low.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.low(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.low(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        ),
        _EquipmentHeader(
          title: context.l10n.rigSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.rig),
          interactiveIssueIndicator: false,
        ),
        ...fit.body.slots.rig.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.rig(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.rig(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        ),
        if (subsystemSlotCount > 0)
          _EquipmentHeader(
            title: context.l10n.subsystemSlot,
            issues: _collectFitIssuesForSection(
              context,
              ref,
              fitContext,
              _FitIssueSection.subsystem,
            ),
            interactiveIssueIndicator: false,
          ),
        ...SubsystemType.allTypes
            .take(subsystemSlotCount)
            .map(
              (type) => _AnySlotRow(
                fitContext: fitContext,
                slotIdent: SlotIdentifier.subsystem(type: type),
                slotInfo: fit.body.slots.subsystem[type.index].match(
                  () => SlotInfo.empty(index: type.index),
                  (slot) => SlotInfo.item(
                    state: FitItemState.online,
                    type: const native.OutSlotType.subSystem(),
                    index: type.index,
                    slot: slot,
                  ),
                ),
                interactionOptions: FitInteractionOptions.screenshot,
              ),
            ),
        if (fit.body.slots.service.isNotEmpty)
          _EquipmentHeader(
            title: context.l10n.serviceSlot,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.service),
            interactiveIssueIndicator: false,
          ),
        ...fit.body.slots.service.mapWithIndex(
          (slot, index) => _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.service(index: index),
            slotInfo: slot.match(
              () => SlotInfo.empty(index: index),
              (slot) => SlotInfo.item(
                state: slot.state,
                type: const native.OutSlotType.service(),
                index: index,
                slot: slot,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        ),
        _EquipmentHeader(
          title: context.l10n.drone,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.drone),
          rightInfo: [
            if (droneBayCapacity > 0 || droneBayUsed > 0)
              _HeaderCapacityCounter(suffix: "m³", count: droneBayUsed, total: droneBayCapacity),
          ],
          interactiveIssueIndicator: false,
        ),
        if (fit.body.drones.isEmpty)
          ListTile(title: Text(context.l10n.fitSlotEmpty(slotName: context.l10n.drone))),
        for (int index = 0; index < fit.body.drones.length; index++)
          _AnySlotRow(
            fitContext: fitContext,
            slotIdent: SlotIdentifier.drone(index: index),
            slotInfo: SlotInfo.item(
              state: fit.body.drones[index].state,
              type: native.OutSlotType.droneBay(groupId: index),
              index: index,
              slot: FitModuleItem(
                charge: const Option.none(),
                state: fit.body.drones[index].state,
                itemId: fit.body.drones[index].itemId,
              ),
            ),
            interactionOptions: FitInteractionOptions.screenshot,
          ),
        if (fitContext.ship.fighterTubes > 0) ...[
          _EquipmentHeader(
            title: context.l10n.fighter,
            issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.fighter),
            interactiveIssueIndicator: false,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                _HeaderCapacityCounter(
                  prefix: "H",
                  count: _fighterCountForGroup(const {1653, 4779}, fitContext, ref),
                  total:
                      fitContext.emulated?.hull
                          .getAttribute(EveConstAttrID.fighterHeavySlots)
                          .round() ??
                      0,
                ),
                _HeaderCapacityCounter(
                  prefix: "L",
                  count: _fighterCountForGroup(const {1652, 4777}, fitContext, ref),
                  total:
                      fitContext.emulated?.hull
                          .getAttribute(EveConstAttrID.fighterLightSlots)
                          .round() ??
                      0,
                ),
                _HeaderCapacityCounter(
                  prefix: "S",
                  count: _fighterCountForGroup(const {1537, 4778}, fitContext, ref),
                  total:
                      fitContext.emulated?.hull
                          .getAttribute(EveConstAttrID.fighterSupportSlots)
                          .round() ??
                      0,
                ),
                _HeaderCapacityCounter(
                  suffix: "x",
                  count: fit.body.fighters.length,
                  total: fitContext.ship.fighterTubes,
                ),
                if (fighterHangarCapacity > 0 || fighterHangarUsed > 0)
                  _HeaderCapacityCounter(
                    suffix: "m³",
                    count: fighterHangarUsed,
                    total: fighterHangarCapacity,
                  ),
              ],
            ),
          ),
          const Divider(),
          if (fit.body.fighters.isEmpty)
            ListTile(title: Text(context.l10n.fitSlotEmpty(slotName: context.l10n.fighter))),
          for (int index = 0; index < fit.body.fighters.length; index++)
            _AnySlotRow(
              fitContext: fitContext,
              slotIdent: SlotIdentifier.fighter(index: index),
              slotInfo: SlotInfo.item(
                state: FitItemState.active,
                type: native.OutSlotType.fighter(
                  groupId: fit.body.fighters[index].groupId,
                  ability: fit.body.fighters[index].fighterAbility,
                ),
                index: index,
                slot: FitModuleItem(
                  itemId: fit.body.fighters[index].itemId,
                  charge: const Option.none(),
                  state: FitItemState.active,
                ),
              ),
              interactionOptions: FitInteractionOptions.screenshot,
            ),
        ],
      ],
    );
  }
}

class _ScreenshotAttributeColumn extends ConsumerWidget {
  const _ScreenshotAttributeColumn({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emulated = fitContext.emulated;
    if (emulated == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShipInfo(fitContext: fitContext),
        const Divider(height: 0),
        Capacitor(ship: emulated),
        Weapon(ship: emulated),
        _Resource(
          ship: emulated,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.ship),
        ),
        Hp(ship: emulated, interactionOptions: FitInteractionOptions.screenshot),
        Miscellaneous(ship: emulated),
        Cargo(ship: emulated),
      ],
    );
  }
}

int _fighterCountForGroup(Set<int> groups, FitContext fitContext, WidgetRef ref) {
  var count = 0;
  for (final fighter in fitContext.fit.body.fighters) {
    final typeId = fitContext.resolveOriginTypeId(fighter.itemId);
    if (typeId == null) continue;
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
    if (type == null) continue;
    if (groups.contains(type.groupId)) {
      count += 1;
    }
  }
  return count;
}
