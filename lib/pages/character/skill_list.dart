import "dart:math" as math;

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
  static const double _filterHeaderHeight = 60;

  final ExpansibleController _controller = ExpansibleController();

  int? _selectedGroupId;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _controller.collapse,
          child: Column(
            children: [
              const SizedBox(height: _filterHeaderHeight),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(right: 10),
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
          ),
        ),
        _SkillGroupFilter(
          controller: _controller,
          groups: groups,
          selectedGroupId: _selectedGroupId,
          onSelect: (groupId) => setState(() {
            _selectedGroupId = groupId == _selectedGroupId ? null : groupId;
          }),
        ),
      ],
    );
  }

  static bool _isSkillGroup(pb_groups.Group group) =>
      group.categoryId == EveConstCategoryId.skill && group.published;
}

class _SkillGroupFilter extends StatelessWidget {
  const _SkillGroupFilter({
    required this.controller,
    required this.groups,
    required this.selectedGroupId,
    required this.onSelect,
  });

  final ExpansibleController controller;
  final List<pb_groups.Group> groups;
  final int? selectedGroupId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).scaffoldBackgroundColor;
    final shape = Border(bottom: BorderSide(color: Theme.of(context).dividerColor));
    return ExpansionTile(
      controller: controller,
      backgroundColor: color,
      collapsedBackgroundColor: color,
      title: selectedGroupId == null
          ? Text(context.l10n.characterSkillAllGroups)
          : GroupNameText(groupId: selectedGroupId!),
      shape: shape,
      collapsedShape: shape,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: _SkillGroupGrid(
            groups: groups,
            selectedGroupId: selectedGroupId,
            onSelect: (groupId) {
              controller.collapse();
              onSelect(groupId);
            },
          ),
        ),
      ],
    );
  }
}

class _SkillGroupGrid extends StatelessWidget {
  const _SkillGroupGrid({
    required this.groups,
    required this.selectedGroupId,
    required this.onSelect,
  });

  final List<pb_groups.Group> groups;
  final int? selectedGroupId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const minTileWidth = 88.0;
      const maxColumnCount = 6;
      const spacing = 8.0;
      final columnCount = math.max(
        1,
        math.min(maxColumnCount, constraints.maxWidth ~/ minTileWidth),
      );
      final tileWidth = (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final group in groups)
            SizedBox(
              width: tileWidth,
              child: _SkillGroupCard(
                groupId: group.groupId,
                selected: group.groupId == selectedGroupId,
                onTap: () => onSelect(group.groupId),
              ),
            ),
        ],
      );
    },
  );
}

class _SkillGroupCard extends StatelessWidget {
  const _SkillGroupCard({required this.groupId, required this.selected, this.onTap});

  final int groupId;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: EdgeInsets.symmetric(horizontal: selected ? 3 : 4, vertical: selected ? 3 : 4),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Center(child: GroupNameText(groupId: groupId)),
      ),
    ),
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
  Widget build(BuildContext context) => InkWell(
    onLongPress: () => showItemDetailPage(context, typeId: skill.typeId),
    child: Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 5, left: 25, right: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: TypeNameText(typeId: skill.typeId)),
          _SkillLevelIndicator(level: level, alphaMaxLevel: alphaMaxLevel, onTapLevel: onTapLevel),
        ],
      ),
    ),
  );
}

class _SkillLevelIndicator extends StatelessWidget {
  const _SkillLevelIndicator({required this.level, this.alphaMaxLevel, this.onTapLevel});

  static const double _hitTargetSize = 48;
  static const double _pipSize = 16;

  final int level;
  final int? alphaMaxLevel;
  final ValueChanged<int>? onTapLevel;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: List.generate(5, (index) {
      final skillLevel = index + 1;
      final unavailableToAlpha = alphaMaxLevel != null && skillLevel > alphaMaxLevel!;
      final color = unavailableToAlpha
          ? colorSkillAlphaLimited
          : Theme.of(context).colorScheme.primary;
      final trained = skillLevel <= level;
      final pip = AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: _pipSize,
        height: _pipSize,
        decoration: BoxDecoration(
          color: trained ? color : Colors.transparent,
          border: trained ? null : Border.all(color: color),
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
