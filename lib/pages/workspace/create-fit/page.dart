import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_select_list.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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
      root:
          ref.watch(
            appSettingServiceProvider.select(
              (t) => t.shipSelectListDisplayVariant == TypeListDisplayVariant.category,
            ),
          )
          ? const EveSelectListRoot.category(categoryId: 6)
          : const EveSelectListRoot.marketGroup(marketGroupId: 4),
    ),
  );
}
