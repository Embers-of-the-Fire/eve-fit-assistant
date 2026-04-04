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

  Future<void> _setAmount(int amount) =>
      fitContext.fitWrapper.changeFighterAmount(slotIdent.index, amount);

  Future<void> _changeAmount(int diff) =>
      fitContext.fitWrapper.changeFighterAmountBy(slotIdent.index, diff);

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

  int _resolveAbilityMask(native.Item? fighterItem) {
    if (fighterItem == null) return 0;

    var mask = 0;
    if (fighterItem.getAttribute(EveConstExtendedAttrID.fighterAttackTurretDamagePerSecond) > 0) {
      mask |= _attackTurretBit;
    }
    if (fighterItem.effects.contains(_fighterMissilesEffectId)) {
      mask |= _missilesBit;
    }
    if (fighterItem.effects.contains(_fighterAttackMissileEffectId)) {
      mask |= _attackMissileBit;
    }
    if (fighterItem.effects.contains(_fighterBombEffectId)) {
      mask |= _bombBit;
    }
    return mask;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storedFighter = fitContext.fit.body.fighters.getOrNull(slotIdent.index);
    if (storedFighter == null) {
      return ListTile(title: Text("Unknown Fighter at slot ${slotInfo.index}"));
    }

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
    final fighterItems =
        fitContext.emulated?.modules
            .where(
              (item) => switch (item.slot.slotType) {
                native.OutSlotType_Fighter(:final groupId) => groupId == storedFighter.groupId,
                _ => false,
              },
            )
            .toList() ??
        const <native.Item>[];
    final representative = fighterItems.isEmpty ? null : fighterItems.first;
    final resolvedMaxQuantity =
        representative?.getAttribute(EveConstAttrID.fighterSquadronMaxSize).round() ?? 0;
    final maxQuantity = resolvedMaxQuantity > 0 ? resolvedMaxQuantity : storedFighter.quantity;
    final availableAbilityMask = _resolveAbilityMask(representative);
    final startActions = <SlidableAction>[
      if (storedFighter.quantity != 1)
        SlidableAction(
          onPressed: (_) => _setAmount(1),
          backgroundColor: Colors.green.shade200,
          foregroundColor: Colors.black,
          label: "x1",
          padding: .zero,
        ),
      if (maxQuantity > 1 && storedFighter.quantity != maxQuantity)
        SlidableAction(
          onPressed: (_) => _setAmount(maxQuantity),
          backgroundColor: Colors.green.shade400,
          foregroundColor: Colors.white,
          label: context.l10n.fitActionFill,
          padding: .zero,
        ),
    ];
    final endActions = <SlidableAction>[
      if (storedFighter.quantity > 1)
        SlidableAction(
          onPressed: (_) => _changeAmount(-1),
          autoClose: false,
          backgroundColor: Colors.red.shade400,
          foregroundColor: Colors.white,
          label: "-1",
          padding: .zero,
        ),
      if (maxQuantity <= 1 || storedFighter.quantity < maxQuantity)
        SlidableAction(
          onPressed: (_) => _changeAmount(1),
          autoClose: false,
          backgroundColor: Colors.green.shade400,
          foregroundColor: Colors.black,
          label: "+1",
          padding: .zero,
        ),
      SlidableAction(
        onPressed: (_) => fitContext.fitWrapper.removeFighter(slotIdent.index),
        backgroundColor: colorActionDelete,
        foregroundColor: Colors.white,
        icon: Icons.delete,
        label: context.l10n.delete,
        padding: .zero,
      ),
    ];
    final dpsText = representative == null
        ? null
        : Text(
            "${storedFighter.quantity} x ${representative.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond).toStringAsFixed(1)}/s = ${(representative.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond) * storedFighter.quantity).toStringAsFixed(1)}/s",
          );

    return Slidable(
      startActionPane: startActions.isEmpty
          ? null
          : ActionPane(
              extentRatio: 0.15 * startActions.length,
              motion: const StretchMotion(),
              children: startActions,
            ),
      endActionPane: ActionPane(
        extentRatio: 0.15 * endActions.length,
        motion: const StretchMotion(),
        children: endActions,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => showItemDetailPage(
          context,
          typeId: displayTypeId,
          fitReference: ItemDetailFitReference.module(
            fitId: fitContext.fitId,
            index: slotInfo.index,
          ),
        ),
        child: ListTile(
          leading: EveIcon(icon: typeDef.icon, overlayIcon: metaGroupIcon, size: 35),
          title: LocalizedTypeName(typeId: displayTypeId),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if ((availableAbilityMask & _attackTurretBit) != 0)
                _buildAbilityChip(
                  context: context,
                  bit: _attackTurretBit,
                  icon: Icons.gps_fixed,
                  label: context.l10n.fitFighterAbilityTurret,
                ),
              if ((availableAbilityMask & _missilesBit) != 0)
                _buildAbilityChip(
                  context: context,
                  bit: _missilesBit,
                  icon: Icons.rocket_launch,
                  label: context.l10n.fitFighterAbilityMissiles,
                ),
              if ((availableAbilityMask & _attackMissileBit) != 0)
                _buildAbilityChip(
                  context: context,
                  bit: _attackMissileBit,
                  icon: Icons.flash_on,
                  label: context.l10n.fitFighterAbilityVolley,
                ),
              if ((availableAbilityMask & _bombBit) != 0)
                _buildAbilityChip(
                  context: context,
                  bit: _bombBit,
                  icon: Icons.blur_on,
                  label: context.l10n.fitFighterAbilityBomb,
                ),
              ?dpsText,
            ],
          ),
          trailing: _FighterCountText(count: storedFighter.quantity, total: maxQuantity),
          onTap: () => showItemDetailPage(
            context,
            typeId: displayTypeId,
            fitReference: ItemDetailFitReference.module(
              fitId: fitContext.fitId,
              index: slotInfo.index,
            ),
          ),
        ),
      ),
    );
  }
}

class _FighterCountText extends StatelessWidget {
  const _FighterCountText({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = _fighterSlotCounterColor(count: count, total: total);
    final textStyle = DefaultTextStyle.of(context).style;

    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: "x "),
          TextSpan(
            text: "$count",
            style: textStyle.copyWith(color: color),
          ),
          TextSpan(text: " / $total"),
        ],
      ),
      textAlign: TextAlign.end,
      softWrap: false,
    );
  }
}

Color? _fighterSlotCounterColor({required int count, required int total}) {
  if (count > total) {
    return Colors.red;
  } else if (count < total && total > 0) {
    return Colors.orange;
  } else {
    return null;
  }
}
