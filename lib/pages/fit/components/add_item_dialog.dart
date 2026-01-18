import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/list/eve_select_list.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "add_item_dialog.freezed.dart";

@freezed
abstract class _AddItemDialogMetadata with _$AddItemDialogMetadata {
  const factory _AddItemDialogMetadata({
    required String title,
    required int initialMarketGroupId,
    required bool Function(EveSelectListRoot) validator,
  }) = _AddItemDialogMetadataData;
}

Future<int?> showAddItemDialog({
  required BuildContext context,
  required String title,
  required int initialMarketGroupId,
  required bool Function(EveSelectListRoot) validator,
}) {
  final metadata = _AddItemDialogMetadata(
    title: title,
    initialMarketGroupId: initialMarketGroupId,
    validator: validator,
  );
  return showDialog<int>(
    context: context,
    builder: (context) => _AddItemDialog(metadata: metadata),
  );
}

class _AddItemDialog extends ConsumerWidget {
  const _AddItemDialog({required this.metadata});

  final _AddItemDialogMetadata metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppDialog(
    title: metadata.title,
    content: SizedBox(
      width: double.maxFinite,
      child: EveSelectList(
        root: EveSelectListRoot.marketGroup(marketGroupId: metadata.initialMarketGroupId),
        validator: metadata.validator,
        shallPopToSelect: (node) => node is EveSelectListRootType,
        onSelect: (node) => switch (node) {
          EveSelectListRootType(:final typeId) => Navigator.of(context).pop(typeId),
          _ => {},
        },
      ),
    ),
  );
}
