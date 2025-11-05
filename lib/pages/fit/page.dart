import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/components/icon/state_icon.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/output.dart" show $OutSlotTypeCopyWith;
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/debug.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart" hide State;
import "package:freezed_annotation/freezed_annotation.dart";
import "package:loading_indicator/loading_indicator.dart";

part "columns.dart";
part "components/action_icons.dart";
part "components/equipment_header.dart";
part "components/slot_row/empty_slot_row.dart";
part "components/slot_row/slot_row.dart";
part "components/slot_row/tactical_mode_slot.dart";
part "components/warning.dart";
part "identifier.dart";
part "tabs/attributes.dart";
part "tabs/character.dart";
part "tabs/drone.dart";
part "tabs/equipment.dart";
part "tabs/fighter.dart";
part "tabs/utils.dart";
part "wrapper.dart";

part "page.freezed.dart";

@RoutePage()
class FitPage extends StatelessWidget {
  const FitPage({required this.fitId, super.key});

  final String fitId;

  @override
  Widget build(BuildContext context) => _FitPage(fitId: fitId);
}

class _FitPage extends ConsumerWidget {
  const _FitPage({required this.fitId});

  final String fitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitMetadata = ref.watch(fitRegistryManagerProvider.select((t) => t.fits[fitId]));
    if (fitMetadata == null) {
      fatal("Unexpected unreachable error: Invalid fit ID", stackTrace: StackTrace.current);
      throw StateError("Unexpected unreachable: Invalid fit ID $fitId");
    }
    final fit = ref.watch(fitProvider(fitId));
    final ship = ref.watch(bundleCollectionGetTypeProvider(fitMetadata.shipTypeId));
    if (ship == null) {
      fatal("Unknown ship type: ${fitMetadata.shipTypeId}", stackTrace: StackTrace.current);
      throw StateError("Unknown ship type: ${fitMetadata.shipTypeId}");
    }
    final shipName = ref.watch(localizationProvider(ship.typeName.id).select((t) => t ?? ""));

    if (!fit.isInitialized) {
      return Layout(
        title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
        child: const Center(
          child: SizedBox(height: 40, child: LoadingIndicator(indicatorType: Indicator.lineScale)),
        ),
      );
    }

    final shipInfo = ref.watch(bundleCollectionGetShipProvider(fit.fit.body.shipTypeId));

    if (shipInfo == null) {
      fatal("Failed to load ship info: ${fit.fit.body.shipTypeId}", stackTrace: StackTrace.current);
      throw StateError("Failed to load ship info: ${fit.fit.body.shipTypeId}");
    }

    final fitWrapper = FitWrapper(wrapped: ref.read(fitProvider(fitId).notifier));
    final fitContext = FitContext(fit: fit.fit, ship: shipInfo, fitWrapper: fitWrapper);

    return Layout(
      title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
      child: FitDisplayColumns(fitContext: fitContext),
    );
  }
}
