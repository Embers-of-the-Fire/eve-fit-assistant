import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/pages/fit/components/attribute/damage_profile_data.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

Future<FitDamageProfile?> showDamageProfileDialog(BuildContext context) => showDialog<FitDamageProfile>(
  context: context,
  builder: (context) => const _DamageProfileDialog(),
);

class _DamageProfileDialog extends StatefulWidget {
  const _DamageProfileDialog();

  @override
  State<_DamageProfileDialog> createState() => _DamageProfileDialogState();
}

class _DamageProfileDialogState extends State<_DamageProfileDialog> {
  int? _groupIndex;

  void _selectProfile(FitDamageProfile profile) => Navigator.of(context).pop(profile);

  @override
  Widget build(BuildContext context) {
    if (_groupIndex == null) {
      return AppDialog(
        title: context.l10n.fitDamageProfileDialogTitle,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: damageProfileCatalog.length,
            itemBuilder: (context, index) {
              final group = damageProfileCatalog[index];
              return ListTile(
                title: Text(group.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => _groupIndex = index),
              );
            },
          ),
        ),
      );
    }

    final group = damageProfileCatalog[_groupIndex!];
    return AppDialog(
      title: group.name,
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: Text(context.l10n.fitDamageProfileDialogGroupTitle),
              onTap: () => setState(() => _groupIndex = null),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: group.entries.length,
                itemBuilder: (context, index) {
                  final entry = group.entries[index];
                  return ListTile(
                    title: Text(entry.name),
                    onTap: () => _selectProfile(entry.profile),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
