import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:eve_fit_assistant/pages/fit/info/item_info.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:flutter/material.dart';

class SkillTree extends StatefulWidget {
  final bool keepAlive;
  final int rootID;

  const SkillTree({super.key, required this.rootID, this.keepAlive = true});

  @override
  State<SkillTree> createState() => _SkillTreeState();
}

class _SkillTreeState extends State<SkillTree> with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final skillTree = _buildSkillTree(widget.rootID);

    return DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        child: TreeView.simpleTyped(
          showRootNode: false,
          expansionBehavior: ExpansionBehavior.scrollToLastChild,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          expansionIndicatorBuilder: (context, node) =>
              ChevronIndicator.rightDown(tree: node, alignment: Alignment.centerLeft),
          indentation: const Indentation(),
          tree: skillTree,
          onTreeReady: (tree) => tree.expandAllChildren(skillTree, recursive: true),
          builder: (context, node) => SkillListTile(item: node.data!),
        ));
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}

class SkillItem {
  final int skillID;
  final String name;
  final int level;
  final int alphaMaxLevel;

  const SkillItem({
    required this.skillID,
    required this.name,
    required this.level,
    required this.alphaMaxLevel,
  });
}

typedef SkillNode = TreeNode<SkillItem>;

SkillNode _buildSkillTree(int rootID) => _buildSkillTreeImpl(rootID, 1);

SkillNode _buildSkillTreeImpl(int rootID, int level) => SkillNode(
    data: SkillItem(
        skillID: rootID,
        name: GlobalStorage().static.skills[rootID]?.nameZH ?? '未知技能 $rootID',
        level: level,
        alphaMaxLevel: GlobalStorage().static.skills[rootID]?.alphaMaxLevel ?? 0))
  ..addAll((GlobalStorage().static.typeSkills[rootID]?.skills)
      .unwrapOr([]).map((el) => _buildSkillTreeImpl(el.id, el.level)));

class SkillListTile extends StatelessWidget {
  final SkillItem item;
  final bool showHidden;
  final void Function(int)? onTapLevel;

  const SkillListTile({
    super.key,
    required this.item,
    this.showHidden = false,
    this.onTapLevel,
  });

  @override
  Widget build(BuildContext context) => InkWell(
      onLongPress: () => showTypeInfoPage(context, typeID: item.skillID),
      child: Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 5, left: 25, right: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.name),
            _SkillLevelIndicator(
              level: item.level,
              alphaMaxLevel: item.alphaMaxLevel,
              showHidden: showHidden,
              onTapLevel: onTapLevel,
            )
          ],
        ),
      ));
}

class _SkillLevelIndicator extends StatelessWidget {
  final int level;
  final int alphaMaxLevel;
  final bool showHidden;
  final void Function(int)? onTapLevel;

  const _SkillLevelIndicator({
    required this.level,
    required this.alphaMaxLevel,
    required this.showHidden,
    required this.onTapLevel,
  });

  Widget Function({Color? color, Decoration? decoration, required int level}) _getContainer() {
    if (onTapLevel == null) {
      return ({Color? color, Decoration? decoration, required int level}) => Container(
            height: 16,
            width: 16,
            color: color,
            decoration: decoration,
          );
    } else {
      return ({Color? color, Decoration? decoration, required int level}) => InkWell(
          onTap: () => onTapLevel!(level),
          child: Container(
            height: 16,
            width: 16,
            color: color,
            decoration: decoration,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = _getContainer();
    return Row(
      spacing: 6,
      children: List.generate(5, (index) {
        final skillLevel = index + 1;
        if (skillLevel > level) {
          if (showHidden) {
            if (skillLevel > alphaMaxLevel) {
              return builder(
                decoration: BoxDecoration(border: Border.all(color: Colors.yellow.shade700)),
                level: skillLevel,
              );
            } else {
              return builder(
                decoration: BoxDecoration(border: Border.all(color: Colors.blue)),
                level: skillLevel,
              );
            }
          } else {
            return builder(color: Colors.transparent, level: skillLevel);
          }
        } else if (skillLevel <= level && skillLevel > alphaMaxLevel) {
          return builder(color: Colors.yellow.shade700, level: skillLevel);
        } else {
          return builder(color: Colors.blue, level: skillLevel);
        }
      }),
    );
  }
}
