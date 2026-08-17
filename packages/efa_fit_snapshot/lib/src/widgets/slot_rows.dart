import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/src/context.dart";
import "package:efa_fit_snapshot/src/l10n.dart";
import "package:flutter/material.dart";

/// Pre-formatted related values of a module/fighter subtitle row.
class SnapshotRelatedValuesRow extends StatelessWidget {
  const SnapshotRelatedValuesRow({required this.values, super.key});

  final List<SnapshotDisplayValue> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final resolver = SnapshotDisplay.resolverOf(context);
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final value in values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              efaIconImage(
                value.hasIcon()
                    ? resolver?.resolveIconHint(
                            value.icon.hasGraphicId() ? value.icon.graphicId : null,
                            value.icon.hasIconId() ? value.icon.iconId : null,
                          ) ??
                          EfaAssets.unknownIcon
                    : EfaAssets.unknownIcon,
                width: 18,
                height: 18,
              ),
              const SizedBox(width: 4),
              Text(value.text, style: const TextStyle(fontSize: 14)),
            ],
          ),
      ],
    );
  }
}

/// A rack row holding a module: state ring, icon (placeholder), localized
/// name, optional charge and related-value subtitles.
class SnapshotModuleRow extends StatelessWidget {
  const SnapshotModuleRow({required this.module, super.key, this.trailing});

  final SnapshotModule module;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final resolver = SnapshotDisplay.resolverOf(context);
    final type = module.type;

    final subtitle = <Widget>[
      if (module.hasCharge())
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (module.charge.hasQuantity()) Text("${module.charge.quantity} x "),
            EfaTypeIcon(typeId: module.charge.type.typeId, resolver: resolver, size: 18),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                resolveSnapshotName(module.charge.type.names, locale),
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      if (module.relatedValues.isNotEmpty) SnapshotRelatedValuesRow(values: module.relatedValues),
    ];

    return ListTile(
      leading: StateIcon.rect(
        state: efaStateOf(module.state),
        child: EfaTypeIcon(typeId: type.typeId, resolver: resolver, size: 35),
      ),
      title: Text(resolveSnapshotName(type.names, locale)),
      subtitle: subtitle.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: subtitle),
      trailing: trailing,
    );
  }
}

/// An empty rack position with the slot placeholder and 1-based index label.
class SnapshotEmptySlotRow extends StatelessWidget {
  const SnapshotEmptySlotRow({
    required this.index,
    required this.slotName,
    required this.placeholder,
    super.key,
  });

  final int index;
  final String slotName;
  final ImageProvider placeholder;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: BorderedRectAvatar(
      size: 35,
      backgroundColor: colorStatusPassive,
      borderColor: colorStatusPassive,
      image: placeholder,
    ),
    title: Text(context.snapshotL10n.slotEmpty(slotName: slotName)),
    trailing: Text("${index + 1}"),
  );
}

/// Selected tactical mode of a T3 destroyer.
class SnapshotTacticalModeRow extends StatelessWidget {
  const SnapshotTacticalModeRow({required this.mode, super.key});

  final SnapshotTacticalMode mode;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final image = switch (mode.variant) {
      TacticalMode_TacticalModeVariant.DEFENSE => EfaAssets.tacticalModeDefense,
      TacticalMode_TacticalModeVariant.SPEED => EfaAssets.tacticalModeSpeed,
      TacticalMode_TacticalModeVariant.TARGET => EfaAssets.tacticalModeTarget,
      _ => EfaAssets.unknownIcon,
    };
    return ListTile(
      leading: StateIcon.circle(state: EfaItemState.active, image: image),
      title: Text(resolveSnapshotName(mode.type.names, locale)),
    );
  }
}

/// A drone stack row: icon, name, `x N` trailing.
class SnapshotDroneRow extends StatelessWidget {
  const SnapshotDroneRow({required this.drone, super.key});

  final SnapshotDrone drone;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final resolver = SnapshotDisplay.resolverOf(context);
    return ListTile(
      leading: StateIcon.rect(
        state: efaStateOf(drone.state),
        child: EfaTypeIcon(typeId: drone.type.typeId, resolver: resolver, size: 35),
      ),
      title: Text(resolveSnapshotName(drone.type.names, locale)),
      trailing: Text("x ${drone.quantity}"),
    );
  }
}

/// A fighter squadron row: ability chips, weapon math subtitle, `x q / max`.
class SnapshotFighterRow extends StatelessWidget {
  const SnapshotFighterRow({required this.fighter, super.key});

  final SnapshotFighter fighter;

  String _abilityLabel(BuildContext context, SnapshotFighter_Ability ability) {
    final l10n = context.snapshotL10n;
    return switch (ability) {
      SnapshotFighter_Ability.TURRET => l10n.fighterAbilityTurret,
      SnapshotFighter_Ability.MISSILES => l10n.fighterAbilityMissiles,
      SnapshotFighter_Ability.ATTACK_MISSILES => l10n.fighterAbilityAttackMissiles,
      SnapshotFighter_Ability.BOMB => l10n.fighterAbilityBomb,
      _ => "$ability",
    };
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final resolver = SnapshotDisplay.resolverOf(context);
    return ListTile(
      leading: StateIcon.rect(
        state: efaStateOf(fighter.state),
        child: EfaTypeIcon(typeId: fighter.type.typeId, resolver: resolver, size: 35),
      ),
      title: Text(resolveSnapshotName(fighter.type.names, locale)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          if (fighter.abilities.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final ability in fighter.abilities)
                  Chip(label: Text(_abilityLabel(context, ability))),
              ],
            ),
          if (fighter.relatedValues.isNotEmpty)
            SnapshotRelatedValuesRow(values: fighter.relatedValues),
        ],
      ),
      trailing: Text("x ${fighter.quantity} / ${fighter.maxSquadronSize}"),
    );
  }
}
