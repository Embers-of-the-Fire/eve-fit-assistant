import 'package:eve_fit_assistant/storage/static/damage_profile.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_breadcrumb/flutter_breadcrumb.dart';

Future<DamageProfile?> showDamageProfileDialog(BuildContext context) => showDialog(
    context: context,
    builder: (context) => _SetDamageProfileDialog(
          onSelected: (damageProfile) {
            Navigator.of(context).pop(damageProfile);
          },
        ));

class _SetDamageProfileDialog extends StatefulWidget {
  final void Function(DamageProfile) onSelected;

  const _SetDamageProfileDialog({required this.onSelected});

  @override
  State<_SetDamageProfileDialog> createState() => _SetDamageProfileDialogState();
}

class _SetDamageProfileDialogState extends State<_SetDamageProfileDialog> {
  String? damageProfileGroup;

  @override
  Widget build(BuildContext context) {
    late final Iterable<ListTile> list;

    if (damageProfileGroup == null) {
      list = GlobalStorage().static.damageProfiles.values.map((entry) => ListTile(
            title: Text(entry.name),
            onTap: () => setState(() {
              damageProfileGroup = entry.name;
            }),
          ));
    } else {
      list = (GlobalStorage().static.damageProfiles[damageProfileGroup!]?.profiles ?? [])
          .map((el) => ListTile(
                title: Text(el.name),
                onTap: () => widget.onSelected(el.damageProfile),
              ));
    }

    final List<BreadCrumbItem> breadcrumbs = [];
    breadcrumbs.add(BreadCrumbItem(
        onTap: () => setState(() {
              damageProfileGroup = null;
            }),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Text('伤害类型'),
        )));
    if (damageProfileGroup != null) {
      breadcrumbs.add(BreadCrumbItem(
          onTap: () => setState(() {}),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(damageProfileGroup!),
          )));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: AlertDialog(
        title: const Text('修改伤害类型'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        contentTextStyle: const TextStyle(fontSize: 16),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration:
                    const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey))),
                child: BreadCrumb(
                    divider: const Icon(Icons.chevron_right),
                    overflow: ScrollableOverflow(direction: Axis.horizontal, keepLastDivider: true),
                    items: breadcrumbs)),
            Expanded(
                child: SingleChildScrollView(
              child: Column(
                children: list.toList(),
              ),
            ))
          ],
        ),
      ),
    );
  }
}
