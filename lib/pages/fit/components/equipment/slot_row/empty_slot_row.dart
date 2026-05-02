part of "../../../page.dart";

bool Function(EveSelectListRoot) _buildSubsystemValidator({
  required WidgetRef ref,
  required FitContext fitContext,
  required SlotIdentifier slotIdent,
  required SubsystemType type,
}) {
  final baseValidator = slotIdent.validator(ref);

  return (node) {
    if (!baseValidator(node)) return false;

    if (node is EveSelectListRootType) {
      final subsystemDef = ref.watch(bundleCollectionGetSubsystemProvider(node.typeId));
      if (subsystemDef == null) return false;
      if (subsystemDef.subsystemType != type.protoEnum) return false;
      if (subsystemDef.shipTypeId != fitContext.ship.typeId) return false;
    }

    return true;
  };
}

class _EmptySlotRow extends ConsumerWidget {
  const _EmptySlotRow({
    required this.slotIdent,
    required this.slotInfo,
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final SlotIdentifier slotIdent;
  final _EmptySlotInfo slotInfo;
  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

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
        ? _buildSubsystemValidator(
            ref: ref,
            fitContext: fitContext,
            slotIdent: slotIdent,
            type: (slotIdent as SlotIdentifierSubsystem).type,
          )
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
      onTap: interactionOptions.allowMutations
          ? () =>
                showAddItemDialog(
                  context: context,
                  title: slotIdent.localizedAddItemDialogTitle(context),
                  initialMarketGroupId: slotIdent.baseMarketGroupId,
                  validator: validator,
                ).then((found) async {
                  if (found == null) return;
                  await fitContext.fitWrapper.equipSlot(slotIdent, found, ref);
                })
          : null,
      trailing: Text("${slotIdent.asIndexed + 1}"),
    );
  }
}
