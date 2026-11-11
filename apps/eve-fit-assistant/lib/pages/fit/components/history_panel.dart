part of "../page.dart";

/// Shared history content mounted either full-width or in a modal end drawer.
class FitHistoryPanel extends ConsumerWidget {
  const FitHistoryPanel({required this.fitId, this.onClose, super.key});

  final String fitId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(fitHistoryProvider(fitId));
    final editable = ref.watch(fitCheckoutCompatibilityProvider(fitId))?.allowsEditing ?? false;
    final colorScheme = context.theme.colorScheme;

    return Material(
      color: colorScheme.surface,
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.fitHistoryTitle,
                          style: context.theme.textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.fitHistoryEntryCount(count: history.length),
                          style: context.theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.fitHistoryClear,
                    onPressed: editable
                        ? () => ref.read(fitHistoryProvider(fitId).notifier).clear()
                        : null,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                  if (onClose != null)
                    IconButton(
                      tooltip: context.l10n.fitHistoryClose,
                      onPressed: onClose,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final entry = history.entries[index];
                  final isCurrent = index == history.cursor;
                  final isFuture = index > history.cursor;
                  final row = ListTile(
                    selected: isCurrent,
                    enabled: editable,
                    onTap: editable && !isCurrent
                        ? () => ref.read(fitHistoryProvider(fitId).notifier).jumpTo(index)
                        : null,
                    leading: Icon(_fitEditActionIcon(entry.action)),
                    title: Text(
                      _fitEditActionDescription(context, ref, entry.action),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent ? const Icon(Icons.check) : null,
                  );
                  if (!isFuture) return row;
                  return Opacity(opacity: 0.55, child: row);
                },
              ),
            ),
            if (history.length == 1 && history.cursor == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  context.l10n.fitHistoryEmptyHint,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

IconData _fitEditActionIcon(FitEditAction action) => switch (action.kind) {
  FitEditKind.openedFit => Icons.folder_open_outlined,
  FitEditKind.equipModule ||
  FitEditKind.copyModule ||
  FitEditKind.fillModules => Icons.add_circle_outline,
  FitEditKind.removeModule => Icons.remove_circle_outline,
  FitEditKind.addCharge => Icons.battery_charging_full,
  FitEditKind.removeCharge || FitEditKind.clearCharges => Icons.battery_alert_outlined,
  FitEditKind.toggleModuleState => Icons.power_settings_new,
  FitEditKind.setImplant => Icons.psychology_outlined,
  FitEditKind.removeImplant => Icons.psychology_outlined,
  FitEditKind.applyImplantSet => Icons.auto_awesome_outlined,
  FitEditKind.setBooster => Icons.rocket_launch_outlined,
  FitEditKind.removeBooster => Icons.rocket_launch_outlined,
  FitEditKind.systemBuff => Icons.public,
  FitEditKind.systemEffectPreset => Icons.public,
  FitEditKind.clearSystemBuffs => Icons.public,
  FitEditKind.setSecurityStatus => Icons.shield_outlined,
  FitEditKind.setDamageProfile => Icons.adjust,
  FitEditKind.setCharacter => Icons.person_outline,
  FitEditKind.setTacticalMode => Icons.settings_suggest_outlined,
  FitEditKind.clearSlots => Icons.clear_all,
  FitEditKind.adjustSubsystem => Icons.settings_outlined,
  FitEditKind.editDynamicAttributes ||
  FitEditKind.convertDynamic ||
  FitEditKind.mutateDynamic ||
  FitEditKind.revertDynamic => Icons.science_outlined,
  FitEditKind.aiEdit => Icons.auto_awesome,
  FitEditKind.renameFit => Icons.edit_outlined,
  FitEditKind.editDescription => Icons.notes_outlined,
  FitEditKind.setModuleQuantity => Icons.tag,
  FitEditKind.setFighterAbility => Icons.sports_martial_arts_outlined,
  FitEditKind.setDamageTurns => Icons.timer_outlined,
};

String _fitEditActionDescription(BuildContext context, WidgetRef ref, FitEditAction action) {
  final l10n = context.l10n;
  String typeName(int? typeId) {
    if (typeId == null || typeId <= 0) return l10n.fallbackTypeName(typeId: typeId ?? 0);
    final locale = context.locale.languageCode;
    final nameId = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)?.typeName));
    final name = nameId == null ? null : watchLocalizedName(ref, id: nameId.id, locale: locale);
    return (name != null && name.isNotEmpty) ? name : l10n.fallbackTypeName(typeId: typeId);
  }

  String characterName(String? characterId) {
    if (characterId == null) return "";
    final metadata = ref.watch(
      characterRegistryManagerProvider.select((registry) => registry.characters[characterId]),
    );
    return _characterDisplayName(context, characterId, metadata);
  }

  String slotName(FitSlotKind? kind) => switch (kind) {
    FitSlotKind.high => l10n.highSlot,
    FitSlotKind.medium => l10n.midSlot,
    FitSlotKind.low => l10n.lowSlot,
    FitSlotKind.rig => l10n.rigSlot,
    FitSlotKind.subsystem => l10n.subsystemSlot,
    FitSlotKind.service => l10n.serviceSlot,
    FitSlotKind.drone => l10n.drone,
    FitSlotKind.fighter => l10n.fighter,
    FitSlotKind.implant => l10n.implantSlot,
    FitSlotKind.booster => l10n.boosterSlot,
    null => "",
  };

  String presetName(String? presetId) {
    final preset = presetId == null ? null : systemEffectPresetById[presetId];
    if (preset == null) {
      return presetId == null ? "" : l10n.fitEnvironmentUnknownPreset(presetId: presetId);
    }
    return context.locale.languageCode == "zh" ? preset.zh : preset.en;
  }

  String buffName(int? buffId) {
    final entry = buffId == null ? null : systemBuffLibraryById[buffId];
    if (entry == null) return l10n.fitHistoryUnknownBuff(buffId: buffId ?? 0);
    return context.locale.languageCode == "zh" ? entry.zh : entry.en;
  }

  return switch (action.kind) {
    FitEditKind.openedFit => l10n.fitHistoryActionOpened,
    FitEditKind.equipModule => l10n.fitHistoryActionEquipModule(
      typeName: typeName(action.typeId),
      slotName: slotName(action.slotKind),
    ),
    FitEditKind.removeModule => l10n.fitHistoryActionRemoveModule(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.addCharge => l10n.fitHistoryActionAddCharge(
      chargeName: typeName(action.chargeTypeId),
      moduleName: typeName(action.moduleTypeId),
    ),
    FitEditKind.removeCharge => l10n.fitHistoryActionRemoveCharge(
      moduleName: typeName(action.moduleTypeId),
    ),
    FitEditKind.toggleModuleState =>
      action.online
          ? l10n.fitHistoryActionModuleOnline(typeName: typeName(action.typeId))
          : l10n.fitHistoryActionModuleOffline(typeName: typeName(action.typeId)),
    FitEditKind.setImplant => l10n.fitHistoryActionEquipImplant(typeName: typeName(action.typeId)),
    FitEditKind.removeImplant => l10n.fitHistoryActionRemoveImplant(slot: (action.slotId ?? 0) + 1),
    FitEditKind.applyImplantSet => l10n.fitHistoryActionApplyImplantSet(
      setName: _implantSetName(context, ref, action.setId),
    ),
    FitEditKind.setBooster => l10n.fitHistoryActionEquipBooster(typeName: typeName(action.typeId)),
    FitEditKind.removeBooster => l10n.fitHistoryActionRemoveBooster(slot: (action.slotId ?? 0) + 1),
    FitEditKind.systemBuff => switch (action.operation) {
      FitEditOperation.add => l10n.fitHistoryActionSystemBuffAdd(buffName: buffName(action.buffId)),
      FitEditOperation.update => l10n.fitHistoryActionSystemBuffUpdate(
        buffName: buffName(action.buffId),
      ),
      _ => l10n.fitHistoryActionSystemBuffRemove(buffName: buffName(action.buffId)),
    },
    FitEditKind.systemEffectPreset =>
      action.operation == FitEditOperation.remove
          ? l10n.fitHistoryActionSystemPresetRemove(presetName: presetName(action.presetId))
          : l10n.fitHistoryActionSystemPresetApply(presetName: presetName(action.presetId)),
    FitEditKind.setSecurityStatus => l10n.fitHistoryActionSetSecurityStatus(
      value: action.value ?? 0,
    ),
    FitEditKind.setDamageProfile => l10n.fitHistoryActionSetDamageProfile,
    FitEditKind.setCharacter => l10n.fitHistoryActionSetCharacter(
      characterId: characterName(action.characterId),
    ),
    FitEditKind.setTacticalMode => l10n.fitHistoryActionSetTacticalMode(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.clearSlots => l10n.fitHistoryActionClearSlots(slotName: slotName(action.slotKind)),
    FitEditKind.clearCharges => l10n.fitHistoryActionClearCharges(
      slotName: slotName(action.slotKind),
    ),
    FitEditKind.clearSystemBuffs => l10n.fitHistoryActionClearSystemBuffs,
    FitEditKind.adjustSubsystem => l10n.fitHistoryActionAdjustSubsystem(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.editDynamicAttributes => l10n.fitHistoryActionEditDynamic(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.convertDynamic => l10n.fitHistoryActionConvertDynamic(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.mutateDynamic => l10n.fitHistoryActionMutateDynamic(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.revertDynamic => l10n.fitHistoryActionRevertDynamic(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.aiEdit => l10n.fitHistoryActionAiEdit(count: action.opCount ?? 1),
    FitEditKind.renameFit => l10n.fitHistoryActionRename,
    FitEditKind.editDescription => l10n.fitHistoryActionEditDescription,
    FitEditKind.setModuleQuantity => l10n.fitHistoryActionSetQuantity(
      typeName: typeName(action.typeId),
      quantity: action.quantity ?? 0,
    ),
    FitEditKind.setFighterAbility => l10n.fitHistoryActionSetFighterAbility(
      typeName: typeName(action.typeId),
    ),
    FitEditKind.setDamageTurns => l10n.fitHistoryActionSetDamageTurns(
      typeName: typeName(action.typeId),
      turns: action.turns ?? 0,
    ),
    FitEditKind.copyModule => l10n.fitHistoryActionCopyModule(
      typeName: typeName(action.typeId),
      slotName: slotName(action.slotKind),
    ),
    FitEditKind.fillModules => l10n.fitHistoryActionFillModules(
      typeName: typeName(action.typeId),
      slotName: slotName(action.slotKind),
    ),
  };
}

String _implantSetName(BuildContext context, WidgetRef ref, int? setId) {
  if (setId == null) return "";
  final set = ref.watch(repoCollectionProvider.select((c) => c?.getImplantSet(setId)));
  if (set == null) return "$setId";
  final locale = context.locale.languageCode;
  return set.names[locale] ?? set.names["en"] ?? "$setId";
}
