import 'package:eve_fit_assistant/constant/eve/categories.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/widgets/skill_tree.dart';
import 'package:flutter/material.dart';

class CharacterSkillList extends StatefulWidget {
  final Map<int, int> skills;
  final void Function(int, int)? onTapLevel; // skill id, skill level

  const CharacterSkillList({super.key, required this.skills, this.onTapLevel});

  @override
  State<CharacterSkillList> createState() => _CharacterSkillListState();
}

class _CharacterSkillListState extends State<CharacterSkillList> {
  final ExpansionTileController _controller = ExpansionTileController();

  int? _selectedGroup;

  @override
  Widget build(BuildContext context) {
    final shape = Border(bottom: BorderSide(color: Theme.of(context).dividerColor));
    final color = Theme.of(context).scaffoldBackgroundColor;

    final title = _selectedGroup
        .andThen((index) => GlobalStorage().static.groups[index]?.nameZH)
        .unwrapOr('技能列表');

    final skillGroups = GlobalStorage()
        .static
        .groups
        .entries
        .filter((entry) => entry.value.categoryID == categorySkill && entry.value.published)
        .sortedByKey<num>((entry) => entry.key);

    final skills = GlobalStorage()
        .static
        .skills
        .entries
        .filter((u) => _selectedGroup == null || u.value.groupID == _selectedGroup);

    return Stack(children: [
      GestureDetector(
          onTap: () => _controller.collapse(),
          child: Column(children: [
            const SizedBox(height: 60),
            DefaultTextStyle(
                style: const TextStyle(fontSize: 16),
                child: Expanded(
                    child: Container(
                        padding: const EdgeInsets.only(right: 10),
                        child: ListView(
                          children: skills
                              .sortedByKey<num>((el) => el.key)
                              .map((el) => SkillListTile(
                                  showHidden: true,
                                  onTapLevel: (level) => widget.onTapLevel?.call(el.key, level),
                                  item: SkillItem(
                                    skillID: el.key,
                                    name: el.value.nameZH,
                                    level: widget.skills[el.key] ?? 0,
                                    alphaMaxLevel: el.value.alphaMaxLevel,
                                  )))
                              .toList(),
                        ))))
          ])),
      ExpansionTile(
        controller: _controller,
        backgroundColor: color,
        collapsedBackgroundColor: color,
        title: Text(title),
        shape: shape,
        collapsedShape: shape,
        children: [
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 16),
                  child: Table(
                    children: skillGroups
                        .chunkNullPad(4)
                        .map((chunk) => TableRow(
                            children: chunk
                                .map((item) => item
                                    .map<Widget>((g) => _SkillGroupCard(
                                          name: g.value.nameZH,
                                          selected: g.key == _selectedGroup,
                                          onTap: () {
                                            _controller.collapse();
                                            setState(
                                              () => _selectedGroup =
                                                  (_selectedGroup != g.key).thenSome(g.key),
                                            );
                                          },
                                        ))
                                    .unwrapOr(const SizedBox.shrink()))
                                .toList()))
                        .toList(),
                  )))
        ],
      ),
    ]);
  }
}

class _SkillGroupCard extends StatelessWidget {
  final String name;
  final void Function()? onTap;
  final bool selected;

  const _SkillGroupCard({required this.name, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) => Container(
      margin: EdgeInsets.symmetric(horizontal: selected ? 3 : 4, vertical: selected ? 3 : 4),
      child: InkWell(
          onTap: onTap,
          // onTap: () {},
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? Colors.blueAccent : Theme.of(context).dividerColor,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(name),
          )));
}
