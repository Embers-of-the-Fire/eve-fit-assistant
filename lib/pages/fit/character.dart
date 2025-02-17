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
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
            child: Row(spacing: 10, children: <InkWell>[
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (context) => AddImplantGroupDialog(onSelected: (items) {
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
          const Divider(),
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

class AddImplantGroupDialog extends StatefulWidget {
  final void Function(List<int>) onSelected;

  const AddImplantGroupDialog({super.key, required this.onSelected});

  @override
  State<AddImplantGroupDialog> createState() => _AddImplantGroupDialogState();
}

class _AddImplantGroupDialogState extends State<AddImplantGroupDialog> {
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
