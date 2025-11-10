import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_select_list.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/constant/eve.dart" show EveConstCategoryId, EveConstMarketGroupId;
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

part "dialog.dart";

@RoutePage()
class FitCreationPage extends ConsumerWidget {
  const FitCreationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.fitCreationPageTitle,
    child: EveSelectList(
      shallPopToSelect: (t) => switch (t) {
        EveSelectListRootType(typeId: final _) => true,
        _ => false,
      },
      onSelect: (t) => switch (t) {
        EveSelectListRootType(:final typeId) =>
          _showShipCreateDialog(context, ref, shipId: typeId).then((f) {
            if (f != null && context.mounted) {
              unawaited(context.router.popAndPush(FitRoute(fitId: f)));
            }
          }),
        _ => null,
      },
      root:
          ref.watch(
            appSettingServiceProvider.select(
              (t) => t.shipSelectListDisplayVariant == TypeListDisplayVariant.category,
            ),
          )
          ? const EveSelectListRoot.category(categoryId: EveConstCategoryId.ship)
          : const EveSelectListRoot.marketGroup(marketGroupId: EveConstMarketGroupId.ship),
    ),
  );
}
