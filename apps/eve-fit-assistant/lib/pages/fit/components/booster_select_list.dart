import "package:efa_constant/eve.dart";
import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/market_groups.pb.dart" as pb_market;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:efa_proto/utils.pb.dart" as pb_utils;
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/list/select_list.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/type_sort.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// One family bucket inside a booster slot section: the types sharing a leaf
/// market group, or the catch-all "Other" bucket for types without one.
class BoosterFamilyGroup {
  const BoosterFamilyGroup({required this.label, required this.typeIds, this.icon});

  final String label;
  final List<int> typeIds;
  final pb_utils.Icon? icon;
}

/// One booster slot section of the picker: every published type carrying this
/// booster slot, subdivided into market-group families where available.
class BoosterSlotSection {
  const BoosterSlotSection({
    required this.slotIndex,
    required this.label,
    required this.families,
    this.icon,
  });

  final int slotIndex;
  final String label;
  final List<BoosterFamilyGroup> families;
  final pb_utils.Icon? icon;
}

/// Assembles the booster picker content from slot metadata instead of the
/// market tree: many boosters (Serenity harvest doses, cerebral accelerators,
/// event items) carry a booster slot but sit outside the Boosters market
/// group — or any market group at all — so a market-tree picker can never
/// show them.
///
/// [names] maps localization ids (market group names) to resolved strings.
/// Market groups serve only as *labels*: a section takes its name/icon from
/// the topmost market group whose published booster subtree shares exactly
/// its slot; families take leaf group names, everything else falls into a
/// trailing "Other" bucket.
List<BoosterSlotSection> buildBoosterSlotSections({
  required Map<int, Slots_BoosterSlot> boosterSlots,
  required pb_types.Type? Function(int typeId) typeOf,
  required Iterable<pb_market.MarketGroup> marketGroups,
  required Map<int, String> names,
  required String Function(int slotIndex) slotFallbackLabel,
  required String otherLabel,
  int? slotFilter,
}) {
  // Hierarchy decisions (subtree slot sets, section groups) must see every
  // published slot: filtering first would let a lone slot claim aggregate
  // groups like "Booster" as its section. The slot filter applies only when
  // constructing the visible section contents below.
  final publishedSlots = <int, int>{}; // typeId -> slotIndex
  for (final entry in boosterSlots.entries) {
    final typeId = entry.key;
    if (typeOf(typeId)?.published != true) continue;
    publishedSlots[typeId] = entry.value.slotIndex;
  }
  final visible = <int, int>{};
  for (final entry in publishedSlots.entries) {
    if (slotFilter != null && entry.value != slotFilter) continue;
    visible[entry.key] = entry.value;
  }

  final groupsById = {for (final group in marketGroups) group.marketGroupId: group};
  final subtreeSlotSets = <int, Set<int>>{};
  Set<int> subtreeSlotSetOf(int groupId, [Set<int>? visiting]) {
    final cached = subtreeSlotSets[groupId];
    if (cached != null) return cached;
    final group = groupsById[groupId];
    if (group == null) return const {};
    final seen = (visiting ?? {})..add(groupId);
    final slots = <int>{};
    for (final typeId in group.types) {
      final slot = publishedSlots[typeId];
      if (slot != null) slots.add(slot);
    }
    for (final childId in group.groups) {
      if (seen.contains(childId)) continue;
      slots.addAll(subtreeSlotSetOf(childId, seen));
    }
    if (visiting == null) subtreeSlotSets[groupId] = slots;
    return slots;
  }

  // Section label candidate for a slot: the shallowest market group below the
  // booster root's parent ("Implants & Boosters") whose published booster
  // subtree occupies exactly that slot — e.g. the "Booster Slot 01" branch or
  // the "Cerebral Accelerators" sibling, never the aggregate roots and never
  // a single-family leaf like "Blue Pill".
  final groupDepths = <int, int>{};
  final boosterRoot = groupsById[EveConstMarketGroupId.booster];
  final sectionRoot = boosterRoot != null && boosterRoot.hasParentGroupId()
      ? groupsById[boosterRoot.parentGroupId]
      : null;
  if (sectionRoot != null) {
    final visited = <int>{sectionRoot.marketGroupId};
    var frontier = sectionRoot.groups.toList();
    var depth = 1;
    while (frontier.isNotEmpty) {
      final next = <int>[];
      for (final groupId in frontier) {
        if (!visited.add(groupId)) continue;
        groupDepths[groupId] = depth;
        next.addAll(groupsById[groupId]?.groups ?? const []);
      }
      frontier = next;
      depth++;
    }
  }

  int? sectionGroupOf(int slotIndex) {
    int? best;
    for (final group in groupsById.values) {
      final depth = groupDepths[group.marketGroupId];
      if (depth == null) continue;
      final slots = subtreeSlotSetOf(group.marketGroupId);
      if (slots.length != 1 || slots.single != slotIndex) continue;
      if (best == null) {
        best = group.marketGroupId;
        continue;
      }
      final bestDepth = groupDepths[best]!;
      if (depth < bestDepth || (depth == bestDepth && group.marketGroupId < best)) {
        best = group.marketGroupId;
      }
    }
    return best;
  }

  String nameOf(pb_market.MarketGroup group) => names[group.marketGroupName.id] ?? "";
  final sections = <BoosterSlotSection>[];
  final bySlotIndex = <int, List<int>>{};
  for (final entry in visible.entries) {
    bySlotIndex.putIfAbsent(entry.value, () => []).add(entry.key);
  }

  for (final slotIndex in bySlotIndex.keys.toList()..sort()) {
    final typeIds = bySlotIndex[slotIndex]!;
    final sectionGroupId = sectionGroupOf(slotIndex);
    final sectionGroup = sectionGroupId == null ? null : groupsById[sectionGroupId];

    final familyTypeIds = <int, List<int>>{}; // marketGroupId -> typeIds
    final otherTypeIds = <int>[];
    for (final typeId in typeIds) {
      final marketGroupId = typeOf(typeId)?.marketGroupId ?? 0;
      final group = groupsById[marketGroupId];
      final isOwnFamily =
          group != null &&
          marketGroupId != sectionGroupId &&
          subtreeSlotSetOf(marketGroupId).length == 1;
      if (isOwnFamily) {
        familyTypeIds.putIfAbsent(marketGroupId, () => []).add(typeId);
      } else {
        otherTypeIds.add(typeId);
      }
    }

    int compareTypeIds(int left, int right) {
      final leftType = typeOf(left);
      final rightType = typeOf(right);
      if (leftType == null || rightType == null) return left.compareTo(right);
      return compareTypesByMeta(leftType, rightType);
    }

    final families = <BoosterFamilyGroup>[
      for (final entry in familyTypeIds.entries)
        BoosterFamilyGroup(
          label: nameOf(groupsById[entry.key]!),
          icon: groupsById[entry.key]!.icon,
          typeIds: entry.value..sort(compareTypeIds),
        ),
    ]..sort((left, right) => left.label.compareTo(right.label));
    if (otherTypeIds.isNotEmpty) {
      families.add(
        BoosterFamilyGroup(label: otherLabel, typeIds: otherTypeIds..sort(compareTypeIds)),
      );
    }

    final sectionName = sectionGroup == null ? "" : nameOf(sectionGroup);
    sections.add(
      BoosterSlotSection(
        slotIndex: slotIndex,
        label: sectionName.isEmpty ? slotFallbackLabel(slotIndex) : sectionName,
        icon: sectionGroup?.icon,
        families: families,
      ),
    );
  }

  return sections;
}

/// Collects the localization ids whose resolution [buildBoosterSlotSections]
/// needs in its names map: section and family market group names.
Set<int> collectBoosterSectionNameIds(Iterable<pb_market.MarketGroup> marketGroups) => {
  for (final group in marketGroups) group.marketGroupName.id,
};

/// Shows the booster picker dialog, returning the chosen type id.
///
/// Resolves the market group names used as section/family labels up front so
/// the list itself can stay synchronous.
Future<int?> showBoosterSelectDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  int? slotFilter,
}) async {
  final collection = ref.read(repoCollectionProvider);
  if (collection == null) return null;

  final locale = ref.read(localeProvider).name;
  final localization = await ref.read(localizationDbServiceProvider.future);
  final names =
      await localization?.localizedNames(
        collectBoosterSectionNameIds(collection.getAllMarketGroups()),
        locale,
      ) ??
      const {};
  if (!context.mounted) return null;

  final sections = buildBoosterSlotSections(
    boosterSlots: collection.slots.boosterSlots,
    typeOf: collection.getType,
    marketGroups: collection.getAllMarketGroups(),
    names: names,
    slotFallbackLabel: (slotIndex) => "${context.l10n.boosterSlot} $slotIndex",
    otherLabel: context.l10n.fitBoosterFamilyOther,
    slotFilter: slotFilter,
  );
  if (sections.isEmpty) return null;
  if (!context.mounted) return null;

  return showDialog<int>(
    context: context,
    builder: (context) =>
        _BoosterSelectDialog(title: title, sections: sections, slotFiltered: slotFilter != null),
  );
}

sealed class _BoosterPickNode {
  const _BoosterPickNode();
}

final class _BoosterPickRoot extends _BoosterPickNode {
  const _BoosterPickRoot();
}

final class _BoosterPickSlot extends _BoosterPickNode {
  const _BoosterPickSlot(this.section);

  final BoosterSlotSection section;
}

final class _BoosterPickFamily extends _BoosterPickNode {
  const _BoosterPickFamily(this.family);

  final BoosterFamilyGroup family;
}

final class _BoosterPickType extends _BoosterPickNode {
  const _BoosterPickType(this.typeId);

  final int typeId;
}

class _BoosterSelectDialog extends ConsumerWidget {
  const _BoosterSelectDialog({
    required this.title,
    required this.sections,
    required this.slotFiltered,
  });

  final String title;
  final List<BoosterSlotSection> sections;
  final bool slotFiltered;

  List<_BoosterPickNode> _childrenOf(_BoosterPickNode node) => switch (node) {
    _BoosterPickRoot() => [
      // With a slot filter the slot level is redundant: start at families.
      if (slotFiltered)
        for (final family in sections.single.families) _BoosterPickFamily(family)
      else
        for (final section in sections) _BoosterPickSlot(section),
    ],
    _BoosterPickSlot(:final section) => [
      for (final family in section.families) _BoosterPickFamily(family),
    ],
    _BoosterPickFamily(:final family) => [
      for (final typeId in family.typeIds) _BoosterPickType(typeId),
    ],
    _BoosterPickType() => const [],
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) => AppDialog(
    title: title,
    content: SizedBox(
      width: double.maxFinite,
      child: SelectList<_BoosterPickNode>(
        root: const _BoosterPickRoot(),
        fetchChildren: (node, ref) => _childrenOf(node),
        shallSelect: (node) => node is _BoosterPickType,
        onSelect: (node) => switch (node) {
          _BoosterPickType(:final typeId) => Navigator.of(context).pop(typeId),
          _ => {},
        },
        returnBehavior: ref.watch(
          appSettingServiceProvider.select((setting) => setting.typeListReturnBehavior),
        ),
        breadcrumbBuilder: (node) => Padding(
          padding: const .symmetric(horizontal: 4),
          child: switch (node) {
            _BoosterPickRoot() => Text(title),
            _BoosterPickSlot(:final section) => Text(section.label),
            _BoosterPickFamily(:final family) => Text(family.label),
            _BoosterPickType(:final typeId) => TypeNameText(typeId: typeId),
          },
        ),
        itemBuilder: (node, onTap) => switch (node) {
          _BoosterPickSlot(:final section) => ListTile(
            leading: section.icon == null
                ? const Icon(Icons.list)
                : EveIcon(icon: section.icon!, acceptGraphic: false),
            title: Text(section.label),
            onTap: onTap,
          ),
          _BoosterPickFamily(:final family) => ListTile(
            leading: family.icon == null
                ? const Icon(Icons.list)
                : EveIcon(icon: family.icon!, acceptGraphic: false),
            title: Text(family.label),
            onTap: onTap,
          ),
          _BoosterPickType(:final typeId) => TypeListTile(
            typeId: typeId,
            fallbackLeading: const Image(image: ImageAssets.unknownIcon, height: 32),
            onTap: onTap,
            onLongPress: () => showItemDetailPage(context, typeId: typeId),
          ),
          _BoosterPickRoot() => const SizedBox.shrink(),
        },
      ),
    ),
  );
}
