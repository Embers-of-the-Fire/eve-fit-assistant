part of 'fit.dart';

class CharacterTab extends ConsumerWidget {
  final String fitID;

  final ScrollController _controller = ScrollController();

  CharacterTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return Container(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        children: [
          ListTile(
            onTap: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (context) => const _SelectCharacterDialog(),
              );
              if (selected == null || selected == fit.character.id) return;
              await fitNotifier.setCharacter(selected);
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: const Icon(Icons.account_circle, size: 30),
            ),
            title: Text(fit.character.name),
          ),
          const Divider(height: 0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(spacing: 10, children: <InkWell>[
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => _AddImplantGroupDialog(onSelected: (items) {
                    final slots = items.filterMap((item) =>
                        GlobalStorage().static.typeSlot.implant[item].map((i) => (item, i)));
                    Navigator.pop(context);
                    fitNotifier.modify((record) {
                      for (final (id, slot) in slots) {
                        record.modifyImplant(
                          slot.slot,
                          (_) => SlotItem(itemID: id, chargeID: null, state: SlotState.online),
                        );
                      }
                      return record;
                    });
                  }),
                ),
                child: const Icon(Icons.add),
              ),
              InkWell(
                onTap: () => fitNotifier.modify((record) {
                  record.clearImplant();
                  return record;
                }),
                child: const Icon(Icons.clear_all),
              )
            ]),
          ),
          const Divider(height: 8),
          Expanded(
              child: ListView(
            controller: _controller,
            children: [
              ...fit.fit.body.implant.enumerate().map((t) {
                final index = t.$1;
                final el = t.$2;
                return getSlotRow(fitID, el, type: FitItemType.implant, index: index);
              })
            ],
          )),
        ],
      ),
    );
  }
}

class _SelectCharacterDialog extends StatelessWidget {
  const _SelectCharacterDialog();

  @override
  Widget build(BuildContext context) {
    final characters = GlobalStorage().character.brief.values;
    final characterList = characters.map((el) => ListTile(
          onTap: () => Navigator.of(context).pop(el.id),
          title: Text(el.name),
        ));

    return Container(
        padding: const EdgeInsets.symmetric(vertical: 120),
        child: AlertDialog(
            title: const Text('修改角色'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            contentTextStyle: const TextStyle(fontSize: 16),
            content: SingleChildScrollView(
              child: Column(
                children: characterList.toList(),
              ),
            )));
  }
}

class _AddImplantGroupDialog extends StatefulWidget {
  final void Function(List<int>) onSelected;

  const _AddImplantGroupDialog({required this.onSelected});

  @override
  State<_AddImplantGroupDialog> createState() => _AddImplantGroupDialogState();
}

class _AddImplantGroupDialogState extends State<_AddImplantGroupDialog> {
  String? implantGroup;

  @override
  Widget build(BuildContext context) {
    late final Iterable<ListTile> list;

    if (implantGroup == null) {
      list = GlobalStorage().static.implantGroups.map((group) => ListTile(
            title: Text(group.name),
            onTap: () => setState(() {
              implantGroup = group.name;
            }),
          ));
    } else {
      list = GlobalStorage()
          .static
          .implantGroups
          .find((u) => u.name == implantGroup)
          .map((i) => i.groups)
          .unwrapOr([]).map((el) => ListTile(
                title: Text(el.name),
                onTap: () => widget.onSelected(el.items),
              ));
    }

    final List<BreadCrumbItem> breadcrumbs = [];
    breadcrumbs.add(BreadCrumbItem(
        onTap: () => setState(() {
              implantGroup = null;
            }),
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Text('植入体组'),
        )));
    if (implantGroup != null) {
      breadcrumbs.add(BreadCrumbItem(
          onTap: () => setState(() {}),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(implantGroup!),
          )));
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: AlertDialog(
        title: const Text('添加植入体组'),
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
