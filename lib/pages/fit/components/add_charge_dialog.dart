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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = ref.watch(bundleCollectionGetAllTypesProvider);
    final groupedTypes = <int, List<int>>{for (final groupId in chargeGroups) groupId: <int>[]};

    for (final type in types) {
      if (groupedTypes.containsKey(type.groupId)) {
        groupedTypes[type.groupId]!.add(type.typeId);
      }
    }

    for (final entries in groupedTypes.values) {
      entries.sort();
    }

    return AppDialog(
      title: context.l10n.fitAddItemDialogTitle(slotName: context.l10n.charge),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final groupId in chargeGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: GroupNameText(groupId: groupId),
              ),
              ...groupedTypes[groupId]!.map(
                (typeId) => TypeListTile(
                  typeId: typeId,
                  onTap: () => Navigator.of(context).pop(typeId),
                  onLongPress: () => showItemDetailPage(context, typeId: typeId),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
