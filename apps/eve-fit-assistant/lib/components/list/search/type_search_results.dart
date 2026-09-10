import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

/// Flat result list shown by item pickers while a search query is active.
///
/// Renders one [TypeListTile] per id with the standard long-press item
/// detail; [onSelect] receives the tapped type id.
class TypeSearchResults extends StatelessWidget {
  const TypeSearchResults({required this.typeIds, super.key, this.onSelect});

  final List<int> typeIds;
  final void Function(int typeId)? onSelect;

  @override
  Widget build(BuildContext context) {
    if (typeIds.isEmpty) {
      return Center(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: Text(
            context.l10n.typeSearchNoResults,
            style: context.theme.textTheme.titleMedium?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: typeIds.length,
      itemBuilder: (context, index) {
        final typeId = typeIds[index];
        return TypeListTile(
          typeId: typeId,
          fallbackLeading: const Image(image: ImageAssets.unknownIcon, height: 32),
          onTap: onSelect == null ? null : () => onSelect!(typeId),
          onLongPress: () => showItemDetailPage(context, typeId: typeId),
        );
      },
    );
  }
}
