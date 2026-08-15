import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/src/context.dart";
import "package:efa_fit_snapshot/src/l10n.dart";
import "package:efa_fit_snapshot/src/widgets/slot_rows.dart";
import "package:flutter/material.dart";

/// Character column: skill profile header, implant slots and boosters.
class SnapshotCharacterColumn extends StatelessWidget {
  const SnapshotCharacterColumn({required this.snapshot, super.key});

  final FitSnapshot snapshot;

  String _characterName(BuildContext context) {
    final character = snapshot.character;
    final locale = Localizations.localeOf(context);
    if (character.names.isNotEmpty) {
      return resolveSnapshotName(character.names, locale);
    }
    final l10n = context.snapshotL10n;
    return switch (character.builtin) {
      SnapshotCharacter_Builtin.ALL_5 => l10n.skillProfileAll5,
      SnapshotCharacter_Builtin.ALL_0 => l10n.skillProfileAll0,
      SnapshotCharacter_Builtin.ALPHA_MAX => l10n.skillProfileAlphaMax,
      _ => "",
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.snapshotL10n;
    final locale = Localizations.localeOf(context);
    final resolver = SnapshotDisplay.resolverOf(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(_characterName(context), textAlign: TextAlign.center),
        ),
        const Divider(height: 4),
        EfaSectionHeader(title: l10n.implantSlot),
        for (final implant in snapshot.implants)
          implant.hasItem()
              ? SnapshotModuleRow(module: implant.item)
              : ListTile(
                  leading: const BorderedRectAvatar(
                    size: 35,
                    backgroundColor: colorStatusPassive,
                    borderColor: colorStatusPassive,
                    icon: Icons.add_circle_outline,
                  ),
                  title: Text(l10n.slotEmpty(slotName: l10n.implantSlot)),
                  trailing: Text("${implant.slotIndex}"),
                ),
        EfaSectionHeader(title: l10n.boosterSlot),
        if (snapshot.boosters.isEmpty)
          ListTile(title: Text(l10n.slotEmpty(slotName: l10n.boosterSlot))),
        for (final booster in snapshot.boosters)
          ListTile(
            leading: StateIcon.rect(
              state: efaStateOf(booster.state),
              child: EfaTypeIcon(typeId: booster.type.typeId, resolver: resolver, size: 35),
            ),
            title: Text(resolveSnapshotName(booster.type.names, locale)),
            subtitle: Text("${l10n.boosterSlot} ${booster.slotIndex}"),
          ),
      ],
    );
  }
}
