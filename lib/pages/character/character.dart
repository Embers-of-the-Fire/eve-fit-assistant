import 'package:eve_fit_assistant/native/codegen/constant/character.dart';
import 'package:eve_fit_assistant/pages/character/char_edit.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class CharacterPage extends StatefulWidget {
  const CharacterPage({super.key});

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  Future<void> _onCopy({required String name, required String id}) async {
    await GlobalStorage().character.create('$name 复制', baseID: id);
    setState(() {});
  }

  Future<void> _onDelete({required String id}) async {
    await GlobalStorage().character.delete(id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('角色配置'),
        ),
        body: SafeArea(
            bottom: true,
            child: Column(
              children: [
                ListTile(
                    shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    leading: const SizedBox.shrink(),
                    title: const Text('默认角色')),
                ...[
                  GlobalStorage().character.predefinedAll5,
                  GlobalStorage().character.predefinedAlphaMax,
                  GlobalStorage().character.predefinedAll0,
                ].map((el) => _CharacterListTile(
                      characterID: el.id,
                      onCopy: () => _onCopy(name: el.name, id: el.id),
                    )),
                ListTile(
                    shape: Border.symmetric(
                        horizontal: BorderSide(color: Theme.of(context).dividerColor)),
                    leading: Ink(
                        decoration: const BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(20))),
                        child: InkWell(
                          onTap: () => _onCopy(
                              name: GlobalStorage().character.predefinedAll5.name,
                              id: GlobalStorage().character.predefinedAll5.id),
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                          child: const Icon(Icons.add_circle_outline),
                        )),
                    title: const Text('自定义角色')),
                Expanded(
                    child: ListView(
                  children: GlobalStorage()
                      .character
                      .brief
                      .values
                      .filter((t) =>
                          t.id != predefinedLevelAll0 &&
                          t.id != predefinedLevelAll5 &&
                          t.id != predefinedLevelAlphaMax)
                      .sortedByKey<Reversed<num>>((el) => Reversed(el.lastModifyTime))
                      .map((el) => _CharacterListTile(
                            characterID: el.id,
                            onCopy: () => _onCopy(name: el.name, id: el.id),
                            onEdit: () => showCharacterEditPage(context, id: el.id)
                                .then((_) => setState(() {})),
                            onDelete: () => _onDelete(id: el.id),
                          ))
                      .toList(),
                ))
              ],
            )),
      );
}

class _CharacterListTile extends StatelessWidget {
  final String characterID;
  final void Function()? onCopy;
  final void Function()? onEdit;
  final void Function()? onDelete;

  const _CharacterListTile({required this.characterID, this.onCopy, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final character = GlobalStorage().character.brief[characterID]!;

    final List<SlidableAction> startActions = [];
    if (onCopy != null) {
      startActions.add(SlidableAction(
        onPressed: (_) => onCopy!(),
        padding: EdgeInsets.zero,
        icon: Icons.copy,
        label: '复制',
      ));
    }
    if (onEdit != null) {
      startActions.add(SlidableAction(
        onPressed: (_) => onEdit!(),
        padding: EdgeInsets.zero,
        icon: Icons.edit,
        backgroundColor: Colors.green,
        label: '编辑',
      ));
    }

    return Slidable(
      startActionPane: startActions.isNotEmpty.then(() => ActionPane(
            extentRatio: 0.15 * startActions.length,
            motion: const StretchMotion(),
            children: startActions,
          )),
      endActionPane: onDelete.map((fn) => ActionPane(
            extentRatio: 0.15,
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => fn(),
                padding: EdgeInsets.zero,
                icon: Icons.delete_forever,
                backgroundColor: Colors.red,
                label: '删除',
              )
            ],
          )),
      child: ListTile(
        shape: Border(bottom: BorderSide(color: Colors.grey.shade800)),
        leading: const Icon(Icons.account_circle),
        title: Text(character.name),
      ),
    );
  }
}
