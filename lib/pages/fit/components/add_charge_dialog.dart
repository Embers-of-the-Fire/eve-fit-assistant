part of "../page.dart";

Future<int?> showAddChargeDialog({
  required BuildContext context,
  required Iterable<int> chargeGroups,
}) {
  final groups = chargeGroups.toSet().toList()..sort();
  if (groups.isEmpty) return Future.value();

  return showDialog<int>(
    context: context,
    builder: (context) => _AddChargeDialog(chargeGroups: groups),
  );
}

class _AddChargeDialog extends ConsumerWidget {
  const _AddChargeDialog({required this.chargeGroups});

  final List<int> chargeGroups;

  bool _isSupportedChargeNode(WidgetRef ref, EveSelectListRoot node) => switch (node) {
    EveSelectListRootType(:final typeId) => switch (ref.read(
      repoCollectionProvider.select((c) => c?.getType(typeId)),
    )) {
      null => false,
      final type => chargeGroups.contains(type.groupId),
    },
    EveSelectListRootGroup(:final groupId) => chargeGroups.contains(groupId),
    _ => true,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppDialog(
    title: context.l10n.fitAddItemDialogTitle(slotName: context.l10n.charge),
    content: SizedBox(
      width: double.maxFinite,
      child: EveSelectList(
        root: const EveSelectListRoot.marketGroup(marketGroupId: EveConstMarketGroupId.charge),
        validator: (node) => _isSupportedChargeNode(ref, node),
        shallPopToSelect: (node) => node is EveSelectListRootType,
        onSelect: (node) => switch (node) {
          EveSelectListRootType(:final typeId) => Navigator.of(context).pop(typeId),
          _ => {},
        },
      ),
    ),
  );
}
