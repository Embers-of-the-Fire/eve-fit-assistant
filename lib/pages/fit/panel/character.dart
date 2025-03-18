part of 'fit.dart';

class CharacterTab extends ConsumerStatefulWidget {
  final String fitID;

  const CharacterTab({super.key, required this.fitID});

  @override
  ConsumerState createState() => _CharacterTabState();
}

class _CharacterTabState extends ConsumerState<CharacterTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final fitNotifier = ref.read(fitRecordNotifierProvider(widget.fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(widget.fitID));

    return Container(
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        children: [
          ListTile(
            onLongPress: () => showCharacterEditPage(context, id: fit.character.id)
                .then((_) => fitNotifier.refresh()),
            onTap: () async {
              final selected = await showDialog<String>(
                context: context,
                builder: (context) => const _SelectCharacterDialog(),
              );
              if (selected == null) return await fitNotifier.refresh();
              await fitNotifier.setCharacter(selected);
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: const Icon(Icons.account_circle, size: 30),
            ),
            title: Text(fit.character.name),
          ),
          const Divider(height: 0),
          TabBar(
            controller: _controller,
            tabs: const [Tab(text: '植入体'), Tab(text: '增效剂')],
            dividerColor: Colors.transparent,
          ),
          const SizedBox(height: 4),
          Expanded(
              child: TabBarView(controller: _controller, children: [
            _CharacterImplantTab(fitID: widget.fitID),
            _CharacterBoosterTab(fitID: widget.fitID),
          ]))
        ],
      ),
    );
  }
}

class _CharacterImplantTab extends ConsumerWidget {
  final String fitID;

  const _CharacterImplantTab({required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(spacing: 10, children: <InkWell>[
          InkWell(
            onTap: () => showDialog(
              context: context,
              builder: (context) => _AddImplantGroupDialog(onSelected: (items) {
                final slots = items.filterMap(
                    (item) => GlobalStorage().static.typeSlot.implant[item].map((i) => (item, i)));
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
        children: [
          ...fit.fit.body.implant.enumerate().map((t) {
            final index = t.$1;
            final el = t.$2;
            return getSlotRow(fitID, el, type: FitItemType.implant, index: index);
          })
        ],
      )),
    ]);
  }
}

class _CharacterBoosterTab extends ConsumerWidget {
  final String fitID;

  const _CharacterBoosterTab({required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(spacing: 10, children: <InkWell>[
          InkWell(
            onTap: () async {
              final item = await showAddItemDialog(context, type: FitItemType.booster);
              if (item == null) return;
              await fitNotifier.modify((record) {
                record.addBooster(item);
                return record;
              });
            },
            child: const Icon(Icons.add),
          ),
          InkWell(
            onTap: () => fitNotifier.modify((record) {
              record.clearBooster();
              return record;
            }),
            child: const Icon(Icons.clear_all),
          )
        ]),
      ),
      const Divider(height: 8),
      Expanded(
          child: ListView(
        children: [
          ...fit.fit.body.booster.enumerate().map((t) => BoosterSlot(fitID: fitID, index: t.$1))
        ],
      )),
    ]);
  }
}

class BoosterSlot extends ConsumerWidget {
  final String fitID;
  final int index;

  const BoosterSlot({super.key, required this.fitID, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    final item = fit.fit.body.booster[index];
    return Slidable(
        startActionPane: ActionPane(extentRatio: 0.15, motion: const StretchMotion(), children: [
          SlidableAction(
              onPressed: (_) async {
                final newItemID = await showAddItemDialogWithGroup(context,
                    title: '更换增效剂',
                    baseName: '增效剂',
                    fallbackGroupID: boosterMarketGroupID,
                    predicate: (itemID) =>
                        GlobalStorage().static.typeSlot.booster[itemID] != null &&
                        GlobalStorage().static.typeSlot.booster[item.itemID]?.slot ==
                            GlobalStorage().static.typeSlot.booster[itemID]?.slot);
                if (newItemID == null) return;
                await fitNotifier.modify((record) {
                  record.modifyBooster(
                      index,
                      (_) => SlotItem(
                            itemID: newItemID,
                            state: SlotState.online,
                            chargeID: null,
                          ));
                  return record;
                });
              },
              padding: EdgeInsets.zero,
              icon: Icons.change_circle,
              backgroundColor: Colors.green,
              label: '更换')
        ]),
        endActionPane: ActionPane(extentRatio: 0.15, motion: const StretchMotion(), children: [
          SlidableAction(
              onPressed: (_) => fitNotifier.modify((record) {
                    record.removeBooster(index);
                    return record;
                  }),
              padding: EdgeInsets.zero,
              icon: Icons.delete_forever,
              backgroundColor: Colors.red,
              label: '删除'),
        ]),
        child: ListTile(
          onLongPress: () => showItemInfoPage(context,
              typeID: item.itemID, item: fit.output.ship.boosters[index], fitID: fitID),
          leading: StateIcon(
              onTap: () async {
                final newState =
                    item.state == SlotState.online ? SlotState.passive : SlotState.online;
                await fitNotifier.modify((record) {
                  record.modifyBooster(index, (item) => item.copyWith(state: newState));
                  return record;
                });
              },
              state: ItemState.fromInt(item.state.state),
              foregroundImage: GlobalStorage().static.icons.getTypeIconFileImageSync(item.itemID)),
          title: Text(GlobalStorage().static.types[item.itemID]?.nameZH ?? '未知增效剂 ${item.itemID}'),
          trailing: GlobalStorage().static.typeSlot.booster[item.itemID]?.slot.toString().text(),
        ));
  }
}

class _SelectCharacterDialog extends StatefulWidget {
  const _SelectCharacterDialog();

  @override
  State<_SelectCharacterDialog> createState() => _SelectCharacterDialogState();
}

class _SelectCharacterDialogState extends State<_SelectCharacterDialog> {
  @override
  Widget build(BuildContext context) {
    final characters = GlobalStorage().character.brief.values;
    final characterList = characters.map((el) => ListTile(
          onTap: () => Navigator.of(context).pop(el.id),
          onLongPress: () => showCharacterEditPage(context, id: el.id).then((_) => setState(() {})),
          title: Text(el.name),
        ));

    return AppDialog(
        title: '修改角色',
        contentTextStyle: const TextStyle(fontSize: 16),
        content: SingleChildScrollView(
          child: Column(children: characterList.toList()),
        ));
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

    return AppDialog(
      title: '添加植入体组',
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
    );
  }
}
