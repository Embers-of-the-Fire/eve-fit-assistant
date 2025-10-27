import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "eve_list.freezed.dart";

@freezed
abstract class EveListItem with _$EveListItem {
  const factory EveListItem.type({required int typeId, Widget? fallbackIcon}) = _EveListItemType;
  const factory EveListItem.group({required int groupId, Widget? fallbackIcon}) = _EveListItemGroup;
  const factory EveListItem.category({required int categoryId, Widget? fallbackIcon}) =
      _EveListItemCategory;
  const factory EveListItem.marketGroup({required int marketGroupId, Widget? fallbackIcon}) =
      _EveListItemMarketGroup;
}

class EveItemList extends StatelessWidget {
  const EveItemList({super.key, this.items = const [], this.defaultFallbackIcon, this.onSelect});

  final List<EveListItem> items;
  final Widget? defaultFallbackIcon;
  final void Function(EveListItem)? onSelect;

  @override
  Widget build(BuildContext context) => ListView.builder(
    itemBuilder: (context, index) {
      final item = items[index];
      return switch (item) {
        _EveListItemType(:final typeId, :final fallbackIcon) => TypeListTile(
          typeId: typeId,
          fallbackLeading: fallbackIcon ?? defaultFallbackIcon,
          onTap: onSelect.map(
            (select) =>
                () => select(item),
          ),
        ),
        _EveListItemGroup(:final groupId, :final fallbackIcon) => GroupListTile(
          groupId: groupId,
          fallbackLeading: fallbackIcon ?? defaultFallbackIcon,
          onTap: onSelect.map(
            (select) =>
                () => select(item),
          ),
        ),
        _EveListItemCategory(:final categoryId, :final fallbackIcon) => CategoryListTile(
          categoryId: categoryId,
          fallbackLeading: fallbackIcon ?? defaultFallbackIcon,
          onTap: onSelect.map(
            (select) =>
                () => select(item),
          ),
        ),
        _EveListItemMarketGroup(:final marketGroupId, :final fallbackIcon) => MarketGroupListTile(
          marketGroupId: marketGroupId,
          fallbackLeading: fallbackIcon ?? defaultFallbackIcon,
          onTap: onSelect.map(
            (select) =>
                () => select(item),
          ),
        ),
        _ => const SizedBox.shrink(), // unreachable
      };
    },
    itemCount: items.length,
  );
}
