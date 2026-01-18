part of "../../../page.dart";

// TODO: Implement slot size updater when fitting subsystems

class _EmptySlotRow extends ConsumerWidget {
  const _EmptySlotRow({required this.slotIdent, required this.slotInfo, required this.fitContext});

  final SlotIdentifier slotIdent;
  final _EmptySlotInfo slotInfo;
  final FitContext fitContext;

  /// Build a custom validator for subsystem slots that checks:
  /// The subsystem type matches the slot index (CORE=0, DEFENSIVE=1, OFFENSIVE=2, PROPULSION=3)
  ///
  /// This validator ensures that subsystems are installed in the correct slots according to
  /// the T3 cruiser subsystem layout where each of the 4 slots is dedicated to a specific subsystem type.
  bool Function(EveSelectListRoot) _buildSubsystemValidator(WidgetRef ref, SubsystemType type) {
    final baseValidator = slotIdent.validator(ref);

    return (node) {
      // First check base validator
      if (!baseValidator(node)) return false;

      // Additional checks for subsystem type nodes
      if (node is EveSelectListRootType) {
        final subsystemDef = ref.watch(bundleCollectionGetSubsystemProvider(node.typeId));
        if (subsystemDef == null) return false;

        // Check if subsystem type matches the slot index
        if (subsystemDef.subsystemType != type.protoEnum) return false;

        // Check if subsystem is compatible with the current ship
        if (subsystemDef.shipTypeId != fitContext.ship.typeId) return false;
      }

      return true;
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ImageProvider? display = switch (slotIdent) {
      SlotIdentifierHigh _ => ImageAssets.slotHigh,
      SlotIdentifierMedium _ => ImageAssets.slotMedium,
      SlotIdentifierLow _ => ImageAssets.slotLow,
      SlotIdentifierRig _ => ImageAssets.slotRig,
      SlotIdentifierSubsystem(:final type) => switch (type) {
        SubsystemType.core => ImageAssets.slotSubsystemCore,
        SubsystemType.defensive => ImageAssets.slotSubsystemDefensive,
        SubsystemType.offensive => ImageAssets.slotSubsystemOffensive,
        SubsystemType.propulsion => ImageAssets.slotSubsystemPropulsion,
      },
      _ => null,
    };

    // Build appropriate validator - use custom one for subsystems
    final validator = slotIdent is SlotIdentifierSubsystem
        ? _buildSubsystemValidator(ref, (slotIdent as SlotIdentifierSubsystem).type)
        : slotIdent.validator(ref);

    return ListTile(
      leading: BorderedRectAvatar(
        size: 35,
        backgroundColor: colorStatusPassive,
        borderColor: colorStatusPassive,
        image: display,
        icon: display.reverseMap(() => Icons.add_circle_outline),
      ),
      title: Text(context.l10n.fitSlotEmpty(slotName: slotIdent.localizedSlotName(context))),
      onTap: () =>
          showAddItemDialog(
            context: context,
            title: slotIdent.localizedAddItemDialogTitle(context),
            initialMarketGroupId: slotIdent.baseMarketGroupId,
            validator: validator,
          ).then((found) async {
            if (found == null) return;
            await fitContext.fitWrapper.equipSlot(slotIdent, found, ref);
          }),
      trailing: Text("${slotIdent.asIndexed + 1}"),
    );
  }
}
