import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/groups.pb.dart" as pb_groups;
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/skill.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class CharacterSkillList extends ConsumerStatefulWidget {
  const CharacterSkillList({required this.skills, super.key, this.onTapLevel});

  final Map<int, int> skills;
  final void Function(int skillTypeId, int level)? onTapLevel;

  @override
  ConsumerState<CharacterSkillList> createState() => _CharacterSkillListState();
}

class _CharacterSkillListState extends ConsumerState<CharacterSkillList>
    with AutomaticKeepAliveClientMixin {
  int? _selectedGroupId;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final groups = ref.watch(bundleCollectionGetAllGroupsProvider).where(_isSkillGroup).toList()
      ..sort((left, right) => left.groupId.compareTo(right.groupId));
    final skillGroupIds = groups.map((group) => group.groupId).toSet();
    final skills = ref.watch(bundleCollectionGetAllTypesProvider).where((type) {
      if (!type.published) return false;
      if (!skillGroupIds.contains(type.groupId)) return false;
      return _selectedGroupId == null || type.groupId == _selectedGroupId;
    }).toList()..sort((left, right) => left.typeId.compareTo(right.typeId));

    return Column(
      children: [
        _SkillGroupFilter(
          groups: groups,
          selectedGroupId: _selectedGroupId,
          onSelect: (groupId) => setState(() {
            _selectedGroupId = groupId == _selectedGroupId ? null : groupId;
          }),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];
              return _SkillListTile(
                skill: skill,
                level: widget.skills[skill.typeId] ?? 0,
                alphaMaxLevel: skill.alphaCloneMaxLevel,
                onTapLevel: widget.onTapLevel == null
                    ? null
                    : (level) => widget.onTapLevel!(skill.typeId, level),
              );
            },
          ),
        ),
      ],
    );
  }

  static bool _isSkillGroup(pb_groups.Group group) =>
      group.categoryId == EveConstCategoryId.skill && group.published;
}

class _SkillGroupFilter extends StatelessWidget {
  const _SkillGroupFilter({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelect,
  });

  final List<pb_groups.Group> groups;
  final int? selectedGroupId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: selectedGroupId == null
        ? Text(context.l10n.characterSkillAllGroups)
        : GroupNameText(groupId: selectedGroupId!),
    childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final group in groups)
              ChoiceChip(
                selected: group.groupId == selectedGroupId,
                label: GroupNameText(groupId: group.groupId),
                onSelected: (_) => onSelect(group.groupId),
              ),
          ],
        ),
      ),
    ],
  );
}

class _SkillListTile extends StatelessWidget {
  const _SkillListTile({
    required this.skill,
    required this.level,
    this.alphaMaxLevel,
    this.onTapLevel,
  });

  final pb_types.Type skill;
  final int level;
  final int? alphaMaxLevel;
  final ValueChanged<int>? onTapLevel;

  @override
  Widget build(BuildContext context) => ListTile(
    title: TypeNameText(typeId: skill.typeId),
    trailing: _SkillLevelIndicator(
      level: level,
      alphaMaxLevel: alphaMaxLevel,
      onTapLevel: onTapLevel,
    ),
    onLongPress: () => showItemDetailPage(context, typeId: skill.typeId),
  );
}

class _SkillLevelIndicator extends StatelessWidget {
  const _SkillLevelIndicator({required this.level, this.alphaMaxLevel, this.onTapLevel});

  static const double _hitTargetSize = 44;
  static const double _pipSize = 18;

  final int level;
  final int? alphaMaxLevel;
  final ValueChanged<int>? onTapLevel;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: List.generate(5, (index) {
      final skillLevel = index + 1;
      final trained = skillLevel <= level;
      final unavailableToAlpha = alphaMaxLevel != null && skillLevel > alphaMaxLevel!;
      final color = unavailableToAlpha
          ? colorSkillAlphaLimited
          : Theme.of(context).colorScheme.primary;
      final borderColor = trained || unavailableToAlpha
          ? color
          : Theme.of(context).colorScheme.outline;
      final pip = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _pipSize,
        height: _pipSize,
        decoration: BoxDecoration(
          color: trained ? color : Colors.transparent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
      );

      if (onTapLevel == null) {
        return pip;
      }
      return Semantics(
        label: "Skill level $skillLevel",
        button: true,
        selected: trained,
        child: InkWell(
          onTap: () => onTapLevel!(skillLevel),
          borderRadius: BorderRadius.circular(_hitTargetSize / 2),
          child: SizedBox.square(
            dimension: _hitTargetSize,
            child: Center(child: pip),
          ),
        ),
      );
    }),
  );
}
