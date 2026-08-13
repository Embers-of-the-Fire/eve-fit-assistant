import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/list/meta_filter_bar.dart";
import "package:eve_fit_assistant/components/list/select_list.dart";
import "package:eve_fit_assistant/components/skeleton.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/data_readiness.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/type_sort.dart";
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

class EveSelectList extends ConsumerStatefulWidget {
  const EveSelectList({
    required this.root,
    super.key,
    this.validator = _defaultToTrue,
    this.shallPopToSelect = _defaultToFalse,
    this.enableMetaFilter = false,
    this.onSelect,
  });

  final EveSelectListRoot root;
  final bool Function(EveSelectListRoot) validator;
  final bool Function(EveSelectListRoot) shallPopToSelect;
  final bool enableMetaFilter;
  final void Function(EveSelectListRoot)? onSelect;

  @override
  ConsumerState<EveSelectList> createState() => _EveSelectListState();
}

class _EveSelectListState extends ConsumerState<EveSelectList> {
  MetaFilter _metaFilter = const MetaFilter.all();

  static Widget _displayNode(EveSelectListRoot node) => node.when(
    category: (categoryId) => CategoryNameText(categoryId: categoryId),
    group: (groupId) => GroupNameText(groupId: groupId),
    marketGroup: (marketGroupId) => MarketGroupNameText(marketGroupId: marketGroupId),
    type: (typeId) => TypeNameText(typeId: typeId),
  );

  @override
  Widget build(BuildContext context) {
    final collectionLoading = ref.watch(
      dataReadinessProvider.select((DataReadinessState s) => s is DataReadinessLoading),
    );
    if (ref.read(repoCollectionProvider) == null && collectionLoading) {
      return const SelectListSkeleton();
    }

    List<EveSelectListRoot> fetchChildren(EveSelectListRoot root, WidgetRef ref) {
      final validator = widget.validator;
      final List<EveSelectListRoot> children = root.when(
        category: (categoryId) {
          final c = ref.read(repoCollectionProvider);
          if (c == null) return [];
          final groups = c.getAllGroups().where((r) => r.categoryId == categoryId).toList()
            ..sort((a, b) => a.groupId.compareTo(b.groupId));
          return groups
              .map((r) => EveSelectListRoot.group(groupId: r.groupId))
              .where(validator)
              .toList();
        },
        group: (groupId) {
          final c = ref.read(repoCollectionProvider);
          if (c == null) return [];
          final types =
              c
                  .getAllTypes()
                  .where((r) => r.groupId == groupId)
                  .where(widget.enableMetaFilter ? _metaFilter.passes : (_) => true)
                  .toList()
                ..sort(compareTypesByMeta);
          return types
              .map((r) => EveSelectListRoot.type(typeId: r.typeId))
              .where(validator)
              .toList();
        },
        marketGroup: (marketGroupId) {
          final c = ref.read(repoCollectionProvider);
          final marketGroupInfo = c?.getMarketGroup(marketGroupId);
          if (c == null || marketGroupInfo == null) return [];
          final groups = marketGroupInfo.groups
              .map((g) => EveSelectListRoot.marketGroup(marketGroupId: g))
              .where(validator);
          final types =
              marketGroupInfo.types
                  .map(c.getType)
                  .nonNulls
                  .where(widget.enableMetaFilter ? _metaFilter.passes : (_) => true)
                  .toList()
                ..sort(compareTypesByMeta);
          final typeNodes = types
              .map((t) => EveSelectListRoot.type(typeId: t.typeId))
              .where(validator);
          final d = [...groups, ...typeNodes];
          return d;
        },
        type: (_) => const [],
      );
      return children;
    }

    return Column(
      children: [
        if (widget.enableMetaFilter)
          MetaFilterBar(
            filter: _metaFilter,
            onChanged: (filter) => setState(() => _metaFilter = filter),
          ),
        Expanded(
          child: SelectList<EveSelectListRoot>(
            root: widget.root,
            fetchChildren: fetchChildren,
            validator: widget.validator,
            shallSelect: widget.shallPopToSelect,
            onSelect: widget.onSelect,
            returnBehavior: ref.watch(
              appSettingServiceProvider.select((setting) => setting.typeListReturnBehavior),
            ),
            breadcrumbBuilder: (node) =>
                Padding(padding: const .symmetric(horizontal: 4), child: _displayNode(node)),
            itemBuilder: (node, onTap) => node.when(
              category: (categoryId) => CategoryListTile(
                categoryId: categoryId,
                fallbackLeading: const Icon(Icons.list),
                onTap: onTap,
              ),
              group: (groupId) => GroupListTile(
                groupId: groupId,
                fallbackLeading: const Icon(Icons.list),
                onTap: onTap,
              ),
              marketGroup: (marketGroupId) => MarketGroupListTile(
                marketGroupId: marketGroupId,
                fallbackLeading: const Icon(Icons.list),
                onTap: onTap,
              ),
              type: (typeId) => TypeListTile(
                typeId: typeId,
                fallbackLeading: const Image(image: ImageAssets.unknownIcon, height: 32),
                onTap: onTap,
                onLongPress: () => showItemDetailPage(context, typeId: typeId),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
