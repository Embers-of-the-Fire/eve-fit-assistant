import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/list/select_list.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "eve_select_list.freezed.dart";

@freezed
abstract class EveSelectListRoot with _$EveSelectListRoot {
  const factory EveSelectListRoot.category({required int categoryId}) = EveSelectListRootCategory;
  const factory EveSelectListRoot.group({required int groupId}) = EveSelectListRootGroup;
  const factory EveSelectListRoot.marketGroup({required int marketGroupId}) =
      EveSelectListRootMarketGroup;
  const factory EveSelectListRoot.type({required int typeId}) = EveSelectListRootType;
}

bool _defaultToTrue(EveSelectListRoot _) => true;
bool _defaultToFalse(EveSelectListRoot _) => false;

class EveSelectList extends ConsumerWidget {
  const EveSelectList({
    required this.root,
    super.key,
    this.validator = _defaultToTrue,
    this.shallPopToSelect = _defaultToFalse,
    this.onSelect,
  });

  final EveSelectListRoot root;
  final bool Function(EveSelectListRoot) validator;
  final bool Function(EveSelectListRoot) shallPopToSelect;
  final void Function(EveSelectListRoot)? onSelect;

  static Widget _displayNode(EveSelectListRoot node) => node.when(
    category: (categoryId) => CategoryNameText(categoryId: categoryId),
    group: (groupId) => GroupNameText(groupId: groupId),
    marketGroup: (marketGroupId) => MarketGroupNameText(marketGroupId: marketGroupId),
    type: (typeId) => TypeNameText(typeId: typeId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    List<EveSelectListRoot> fetchChildren(EveSelectListRoot root, WidgetRef ref) {
      final List<EveSelectListRoot> children = root.when(
        category: (categoryId) {
          final groups =
              ref
                  .read(bundleCollectionGetAllGroupsProvider)
                  .where((r) => r.categoryId == categoryId)
                  .toList()
                ..sort((a, b) => a.groupId.compareTo(b.groupId));
          return groups
              .map((r) => EveSelectListRoot.group(groupId: r.groupId))
              .where(validator)
              .toList();
        },
        group: (groupId) {
          final types =
              ref
                  .read(bundleCollectionGetAllTypesProvider)
                  .where((r) => r.groupId == groupId)
                  .toList()
                ..sort((a, b) => a.typeId.compareTo(b.typeId));
          return types
              .map((r) => EveSelectListRoot.type(typeId: r.typeId))
              .where(validator)
              .toList();
        },
        marketGroup: (marketGroupId) {
          final marketGroupInfo = ref.read(bundleCollectionGetMarketGroupProvider(marketGroupId));
          if (marketGroupInfo == null) return [];
          final groups = marketGroupInfo.groups
              .map((g) => EveSelectListRoot.marketGroup(marketGroupId: g))
              .where(validator);
          final types = marketGroupInfo.types
              .map((t) => EveSelectListRoot.type(typeId: t))
              .where(validator);
          final d = [...groups, ...types];
          info("$d");
          return d;
        },
        type: (_) => const [],
      );
      return children;
    }

    return SelectList<EveSelectListRoot>(
      root: root,
      fetchChildren: fetchChildren,
      validator: validator,
      shallSelect: shallPopToSelect,
      onSelect: onSelect,
      breadcrumbBuilder: (node) =>
          Padding(padding: const .symmetric(horizontal: 4), child: _displayNode(node)),
      itemBuilder: (node, onTap) => node.when(
        category: (categoryId) => CategoryListTile(
          categoryId: categoryId,
          fallbackLeading: const Icon(Icons.list),
          onTap: onTap,
        ),
        group: (groupId) =>
            GroupListTile(groupId: groupId, fallbackLeading: const Icon(Icons.list), onTap: onTap),
        marketGroup: (marketGroupId) => MarketGroupListTile(
          marketGroupId: marketGroupId,
          fallbackLeading: const Icon(Icons.list),
          onTap: onTap,
        ),
        type: (typeId) => TypeListTile(
          typeId: typeId,
          fallbackLeading: const Image(image: ImageAssets.unknownIcon, height: 32),
          onTap: onTap,
        ),
      ),
    );
  }
}
