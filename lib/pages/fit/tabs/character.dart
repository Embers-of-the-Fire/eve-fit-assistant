part of "../page.dart";

const _maxImplantSlots = 10;

class _CharacterTab extends ConsumerStatefulWidget {
  const _CharacterTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  ConsumerState<_CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends ConsumerState<_CharacterTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final selectedCharacterId = widget.fitContext.fit.body.characterId;
    final selectedCharacter = ref.watch(
      characterRegistryManagerProvider.select(
        (registry) => registry.characters[selectedCharacterId],
      ),
    );

    return Column(
      children: [
        ListTile(
          onTap: widget.interactionOptions.allowMutations
              ? () => _handleSelectCharacter(context, selectedCharacterId)
              : null,
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Icon(Icons.account_circle, size: 30),
          ),
          title: Text(_characterDisplayName(context, selectedCharacterId, selectedCharacter)),
          subtitle: Text(context.l10n.fitTabsCharacter),
          trailing: widget.interactionOptions.allowMutations
              ? const Icon(Icons.keyboard_arrow_right)
              : null,
        ),
        const Divider(height: 0),
        TabBar(
          controller: _controller,
          tabs: [
            Tab(text: context.l10n.implantSlot),
            Tab(text: context.l10n.boosterSlot),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              _CharacterImplantTab(
                fitContext: widget.fitContext,
                interactionOptions: widget.interactionOptions,
              ),
              _CharacterBoosterTab(
                fitContext: widget.fitContext,
                interactionOptions: widget.interactionOptions,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleSelectCharacter(BuildContext context, String selectedCharacterId) async {
    final nextCharacterId = await showDialog<String>(
      context: context,
      builder: (context) => _SelectCharacterDialog(selectedCharacterId: selectedCharacterId),
    );
    if (nextCharacterId == null || nextCharacterId == selectedCharacterId) {
      return;
    }
    await widget.fitContext.fitWrapper.setCharacter(nextCharacterId);
  }
}

class _SelectCharacterDialog extends ConsumerWidget {
  const _SelectCharacterDialog({required this.selectedCharacterId});

  final String selectedCharacterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(characterRegistryManagerProvider);

    return AppDialog(
      title: context.l10n.fitTabsCharacter,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: CharacterRegistryManager.builtInCharacterIds
              .map((characterId) {
                final metadata = registry.characters[characterId];
                final title = _characterDisplayName(context, characterId, metadata);
                return ListTile(
                  selected: characterId == selectedCharacterId,
                  leading: Icon(
                    characterId == selectedCharacterId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(title),
                  onTap: () => Navigator.of(context).pop(characterId),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

String _characterDisplayName(
  BuildContext context,
  String characterId,
  CharacterMetadata? metadata,
) => switch (characterId) {
  predefinedMaxCharacterId => context.l10n.fitSkillProfileAll5,
  predefinedZeroCharacterId => context.l10n.fitSkillProfileAll0,
  _ => metadata?.name ?? characterId,
};

class _CharacterImplantTab extends ConsumerWidget {
  const _CharacterImplantTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final implantAssignments = _buildImplantAssignments(fit, ref);

    return Column(
      children: [
        _EquipmentHeader(
          title: context.l10n.implantSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.implant),
          actions: [
            if (interactionOptions.allowMutations)
              InkWell(onTap: () => _handleAddImplant(context, ref), child: const Icon(Icons.add)),
            if (interactionOptions.allowMutations)
              _ActionClearAll(onTap: fitContext.fitWrapper.clearImplants),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              for (int slotId = 0; slotId < _maxImplantSlots; slotId++)
                if (implantAssignments.containsKey(slotId))
                  _ImplantRow(
                    fitContext: fitContext,
                    slotId: slotId,
                    storageIndex: implantAssignments[slotId]!,
                    interactionOptions: interactionOptions,
                  )
                else
                  _EmptyImplantRow(
                    fitContext: fitContext,
                    slotId: slotId,
                    interactionOptions: interactionOptions,
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddImplant(BuildContext context, WidgetRef ref) async {
    if (fitContext.fit.body.implants.length >= _maxImplantSlots) return;

    final typeId = await showAddItemDialog(
      context: context,
      title: context.l10n.fitAddItemDialogTitle(slotName: context.l10n.implantSlot),
      initialMarketGroupId: EveConstMarketGroupId.implant,
      validator: (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          ref.read(bundleCollectionGetSlotsProvider)?.implantSlots.containsKey(typeId) ?? false,
        _ => true,
      },
    );
    if (typeId == null) return;

    final slotId = ref.read(bundleCollectionGetSlotsProvider)?.implantSlots[typeId]?.slotIndex;
    final storageIndex = slotId == null ? null : slotId - 1;
    if (storageIndex == null || storageIndex < 0 || storageIndex >= _maxImplantSlots) return;
    await fitContext.fitWrapper.equipSlot(SlotIdentifier.implant(index: storageIndex), typeId, ref);
  }
}

class _CharacterBoosterTab extends ConsumerWidget {
  const _CharacterBoosterTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boosters = fitContext.fit.body.boosters;

    return Column(
      children: [
        _EquipmentHeader(
          title: context.l10n.boosterSlot,
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.booster),
          actions: [
            if (interactionOptions.allowMutations)
              InkWell(onTap: () => _handleAddBooster(context, ref), child: const Icon(Icons.add)),
            if (interactionOptions.allowMutations)
              _ActionClearAll(onTap: fitContext.fitWrapper.clearBoosters),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              for (final booster in boosters)
                _BoosterRow(
                  fitContext: fitContext,
                  slotId: booster.index,
                  interactionOptions: interactionOptions,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddBooster(BuildContext context, WidgetRef ref) async {
    const slotIdent = SlotIdentifier.booster(slotId: 1);
    final typeId = await showAddItemDialog(
      context: context,
      title: slotIdent.localizedAddItemDialogTitle(context),
      initialMarketGroupId: slotIdent.baseMarketGroupId,
      validator: (node) => switch (node) {
        EveSelectListRootType(:final typeId) =>
          ref.read(bundleCollectionGetSlotsProvider)?.boosterSlots.containsKey(typeId) ?? false,
        _ => true,
      },
    );
    if (typeId == null) return;

    // Booster types already encode their logical slot in bundle metadata, so
    // add flows can infer the destination slot directly from the chosen type.
    final slotId = ref.read(bundleCollectionGetSlotsProvider)?.boosterSlots[typeId]?.slotIndex;
    if (slotId == null) return;
    await fitContext.fitWrapper.setBooster(slotId, typeId);
  }
}

class _ImplantRow extends ConsumerWidget {
  const _ImplantRow({
    required this.fitContext,
    required this.slotId,
    required this.storageIndex,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final int slotId;
  final int storageIndex;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final implant = fitContext.fit.body.implants[storageIndex];
    final itemId = implant.itemId;
    if (itemId is! FitStorageItemIdItem) {
      return ListTile(title: Text(context.l10n.fitUnknownImplantAtSlot(slot: slotId + 1)));
    }

    final typeDef = ref.watch(bundleCollectionGetTypeProvider(itemId.asId));
    if (typeDef == null) {
      return ListTile(title: Text(context.l10n.fitUnknownImplant(typeId: itemId.asId)));
    }

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(typeDef.metaGroupId).select((t) => t?.icon),
    );

    final content = ListTile(
      leading: StateIcon.rect(
        state: implant.state,
        onTap: interactionOptions.allowStateToggle
            ? () => fitContext.fitWrapper.toggleSlot(SlotIdentifier.implant(index: slotId), ref)
            : null,
        child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
      ),
      title: LocalizedTypeName(typeId: itemId.asId),
      trailing: Text("${slotId + 1}"),
      onLongPress: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: itemId.asId,
              fitReference: ItemDetailFitReference.implant(fitId: fitContext.fitId, index: slotId),
            )
          : null,
    );

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      startActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            // The deprecated page replaced implants in-place for the same slot.
            onPressed: (_) => _handleReplace(context, ref),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.change_circle,
            label: context.l10n.fitActionSet,
            padding: .zero,
          ),
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.removeImplantForSlot(slotId, ref),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: content,
    );
  }

  Future<void> _handleReplace(BuildContext context, WidgetRef ref) async {
    final slotIdent = SlotIdentifier.implant(index: slotId);
    final typeId = await showAddItemDialog(
      context: context,
      title: slotIdent.localizedAddItemDialogTitle(context),
      initialMarketGroupId: slotIdent.baseMarketGroupId,
      validator: slotIdent.validator(ref),
    );
    if (typeId == null) return;
    await fitContext.fitWrapper.equipSlot(slotIdent, typeId, ref);
  }
}

class _EmptyImplantRow extends ConsumerWidget {
  const _EmptyImplantRow({
    required this.fitContext,
    required this.slotId,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final int slotId;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _EmptySlotRow(
    fitContext: fitContext,
    slotIdent: SlotIdentifier.implant(index: slotId),
    slotInfo: _EmptySlotInfo(index: slotId),
    interactionOptions: interactionOptions,
  );
}

class _BoosterRow extends ConsumerWidget {
  const _BoosterRow({
    required this.fitContext,
    required this.slotId,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final int slotId;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booster = fitContext.fit.body.boosters.firstWhere((booster) => booster.index == slotId);

    final itemId = booster.itemId;
    if (itemId is! FitStorageItemIdItem) {
      return ListTile(title: Text(context.l10n.fitUnknownBoosterAtSlot(slot: slotId)));
    }

    final typeDef = ref.watch(bundleCollectionGetTypeProvider(itemId.asId));
    if (typeDef == null) {
      return ListTile(title: Text(context.l10n.fitUnknownBooster(typeId: itemId.asId)));
    }

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(typeDef.metaGroupId).select((t) => t?.icon),
    );

    final content = ListTile(
      leading: StateIcon.rect(
        state: booster.state,
        onTap: interactionOptions.allowStateToggle
            ? () => fitContext.fitWrapper.toggleSlot(SlotIdentifier.booster(slotId: slotId), ref)
            : null,
        child: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
      ),
      title: LocalizedTypeName(typeId: itemId.asId),
      subtitle: Text("${context.l10n.boosterSlot} $slotId"),
      onTap: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: itemId.asId,
              fitReference: ItemDetailFitReference.booster(fitId: fitContext.fitId, index: slotId),
            )
          : null,
      onLongPress: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: itemId.asId,
              fitReference: ItemDetailFitReference.booster(fitId: fitContext.fitId, index: slotId),
            )
          : null,
    );

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      startActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _handleReplace(context, ref),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.change_circle,
            label: context.l10n.fitActionSet,
            padding: .zero,
          ),
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.removeBooster(slotId),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: content,
    );
  }

  Future<void> _handleReplace(BuildContext context, WidgetRef ref) async {
    final slotIdent = SlotIdentifier.booster(slotId: slotId);
    final typeId = await showAddItemDialog(
      context: context,
      title: slotIdent.localizedAddItemDialogTitle(context),
      initialMarketGroupId: slotIdent.baseMarketGroupId,
      validator: _boosterValidator(ref, slotId),
    );
    if (typeId == null) return;
    await fitContext.fitWrapper.setBooster(slotId, typeId);
  }
}

bool Function(EveSelectListRoot) _boosterValidator(WidgetRef ref, int slotId) =>
    (node) => switch (node) {
      EveSelectListRootType(:final typeId) =>
        ref.read(bundleCollectionGetSlotsProvider)?.boosterSlots[typeId]?.slotIndex == slotId,
      _ => true,
    };

Map<int, int> _buildImplantAssignments(FitStorage fit, WidgetRef ref) {
  final slotsInfo = ref.watch(bundleCollectionGetSlotsProvider);
  if (slotsInfo == null) return const {};

  final assignments = <int, int>{};
  for (final (storageIndex, implant) in fit.body.implants.mapWithIndex(
    (implant, index) => (index, implant),
  )) {
    final typeId = switch (implant.itemId) {
      FitStorageItemIdItem(:final id) => id,
      _ => null,
    };
    if (typeId == null) continue;

    final slotId = slotsInfo.implantSlots[typeId]?.slotIndex;
    final storageSlotId = slotId == null ? null : slotId - 1;
    if (storageSlotId == null || storageSlotId < 0 || storageSlotId >= _maxImplantSlots) continue;
    assignments[storageSlotId] ??= storageIndex;
  }
  return assignments;
}
