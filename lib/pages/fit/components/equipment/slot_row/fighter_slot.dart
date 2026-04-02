part of "../../../page.dart";

class _FighterSlotRow extends ConsumerWidget {
  const _FighterSlotRow({
    required this.fitContext,
    required this.slotIdent,
    required this.slotInfo,
  });

  static const int _attackTurretBit = 0x01;
  static const int _missilesBit = 0x02;
  static const int _attackMissileBit = 0x04;
  static const int _bombBit = 0x08;

  final SlotIdentifierFighter slotIdent;
  final _ItemSlotInfo slotInfo;
  final FitContext fitContext;

  Future<void> _toggleAbility(int bit) =>
      fitContext.fitWrapper.toggleFighterAbilityBit(slotIdent.index, bit);

  Widget _buildAbilityChip({
    required BuildContext context,
    required int bit,
    required IconData icon,
    required String label,
  }) {
    final fighter = fitContext.fit.body.fighters[slotIdent.index];
    final enabled = (fighter.fighterAbility & bit) != 0;

    return FilterChip(
      selected: enabled,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (_) => _toggleAbility(bit),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemId = slotInfo.slot.itemId;
    final displayTypeId = fitContext.resolveDisplayTypeId(itemId);
    if (displayTypeId == null) {
      return ListTile(title: Text("Unknown Fighter ${itemId.asId} at slot ${slotInfo.index}"));
    }

    final typeDef = ref.watch(bundleCollectionGetTypeProvider(displayTypeId));
    if (typeDef == null) {
      return ListTile(title: Text("Unknown Fighter $displayTypeId at slot ${slotInfo.index}"));
    }

    final metaGroupIcon = ref.watch(
      bundleCollectionGetMetaGroupProvider(typeDef.metaGroupId).select((t) => t?.icon),
    );

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.3,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.removeFighter(slotIdent.index),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.setFighterAbility(slotIdent.index, 0),
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.restart_alt,
            label: context.l10n.cancel,
            padding: .zero,
          ),
        ],
      ),
      child: ListTile(
        leading: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
        title: LocalizedTypeName(typeId: displayTypeId),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildAbilityChip(
              context: context,
              bit: _attackTurretBit,
              icon: Icons.gps_fixed,
              label: "Turret",
            ),
            _buildAbilityChip(
              context: context,
              bit: _missilesBit,
              icon: Icons.rocket_launch,
              label: "Missiles",
            ),
            _buildAbilityChip(
              context: context,
              bit: _attackMissileBit,
              icon: Icons.flash_on,
              label: "Volley",
            ),
            _buildAbilityChip(context: context, bit: _bombBit, icon: Icons.blur_on, label: "Bomb"),
          ],
        ),
        trailing: Text("#${slotIdent.index + 1}"),
      ),
    );
  }
}
