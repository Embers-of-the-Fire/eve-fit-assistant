import "dart:async";
import "dart:io";
import "dart:math" as math;

import "dart:ui" as ui;

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/icon/bordered_rect_avatar.dart";
import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/icon/state_icon.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/list/eve_select_list.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/components/resonance_box.dart";
import "package:eve_fit_assistant/components/resource_compare.dart";
import "package:eve_fit_assistant/components/skeleton.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/constant/assets.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/data/proto/utils.pb.dart" as pb_utils;
import "package:eve_fit_assistant/features/fit_io/export_dialog.dart";
import "package:eve_fit_assistant/features/market_price/ui/fit_price_tile.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/native/api/validation.dart" as native_validation;
import "package:eve_fit_assistant/pages/fit/components/add_item_dialog.dart";
import "package:eve_fit_assistant/pages/fit/components/attribute/damage_profile_dialog.dart";
import "package:eve_fit_assistant/pages/fit/components/equipment/slot_row/related_values_logic.dart";
import "package:eve_fit_assistant/pages/fit/components/slidable_edge_zone.dart";
import "package:eve_fit_assistant/pages/item-detail/page.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/compatibility_notice.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/native.dart";
import "package:eve_fit_assistant/utils/native_convert.dart";
import "package:eve_fit_assistant/utils/num.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:eve_fit_assistant/utils/subsystem.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_slidable/flutter_slidable.dart";
import "package:fpdart/fpdart.dart" hide State;
import "package:loading_indicator/loading_indicator.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

part "columns.dart";
part "components/action_icons.dart";
part "components/add_charge_dialog.dart";
part "components/attribute/capacitor.dart";
part "components/attribute/cargo.dart";
part "components/attribute/hp.dart";
part "components/attribute/miscellaneous.dart";
part "components/attribute/resource.dart";
part "components/attribute/ship_info.dart";
part "components/attribute/weapon.dart";
part "components/equipment/slot_row/drone_slot.dart";
part "components/equipment/slot_row/empty_slot_row.dart";
part "components/equipment/slot_row/fighter_slot.dart";
part "components/equipment/slot_row/related_values.dart";
part "components/equipment/slot_row/slot_row.dart";
part "components/equipment/slot_row/subsystem_slot.dart";
part "components/equipment/slot_row/tactical_mode_slot.dart";
part "components/equipment_header.dart";
part "components/issue_reporting.dart";
part "components/warning.dart";
part "identifier.dart";
part "screenshot_page.dart";
part "tabs/attributes.dart";
part "tabs/character.dart";
part "tabs/drone.dart";
part "tabs/equipment.dart";
part "tabs/fighter.dart";
part "tabs/utils.dart";
part "wrapper.dart";

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
    final compatibility = ref.watch(fitCheckoutCompatibilityProvider(fitId));
    final compatibilityNotice = localizeFitCheckoutCompatibility(context.l10n, compatibility);
    final repoState = ref.watch(repoStateProvider);
    final repoCollection = ref.watch(repoCollectionProvider);
    final activeCheckout = ref.watch(activeCheckoutProvider);
    final showCheckoutSwitchOverlay = repoState is RepoStateInitializing && activeCheckout.isSome();
    final isCheckoutSwitching = repoState is RepoStateInitializing || repoCollection == null;
    final overlayCheckoutId = ref.watch(activeCheckoutIdProvider).match(() => "", (id) => id);
    if (fitMetadata == null) {
      return Layout(
        title: context.l10n.fitPageUnavailableTitle,
        child: _FitPageErrorState(
          icon: Icons.folder_off_outlined,
          title: context.l10n.fitPageUnavailableTitle,
          message: context.l10n.fitPageMissingMessage,
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.fitPageBackAction),
            ),
          ],
        ),
      );
    }
    final fit = ref.watch(fitProvider(fitId));
    final ship = ref.watch(
      repoCollectionProvider.select((c) => c?.getType(fitMetadata.shipTypeId)),
    );
    if (ship == null) {
      if (isCheckoutSwitching) {
        return Layout(title: fitMetadata.name, child: const FitPageSkeleton());
      }

      if (compatibilityNotice == null) {
        error("Unknown ship type for fit $fitId: ${fitMetadata.shipTypeId}");
      }
      return Layout(
        title: fitMetadata.name,
        child: _FitPageErrorState(
          icon: Icons.directions_boat_filled_outlined,
          title: compatibilityNotice?.title ?? context.l10n.fitPageUnavailableTitle,
          message: compatibilityNotice?.message ?? context.l10n.fitPageShipUnavailableMessage,
          details: "typeId=${fitMetadata.shipTypeId}",
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.fitPageBackAction),
            ),
          ],
        ),
      );
    }
    final locale = context.locale.languageCode;
    final shipName =
        ref.watch(
          repoCollectionProvider.select((c) => c?.getLocalizedName(ship.typeName.id, locale)),
        ) ??
        "";

    if (!fit.isInitialized) {
      if (fit.hasError) {
        return Layout(
          title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
          child: _FitPageErrorState(
            icon: Icons.error_outline,
            title: context.l10n.fitPageUnavailableTitle,
            message: localizeFitErrorMessage(
              context.l10n,
              fit.errorMessageKey ?? FitErrorMessageKey.fitLoadFailed,
            ),
            actions: [
              FilledButton.icon(
                onPressed: ref.read(fitProvider(fitId).notifier).reload,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.fitPageRetryAction),
              ),
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: Text(context.l10n.fitPageBackAction),
              ),
            ],
          ),
        );
      }
      return Layout(
        title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
        child: const Center(
          child: SizedBox(height: 40, child: LoadingIndicator(indicatorType: Indicator.lineScale)),
        ),
      );
    }

    final shipInfo = ref.watch(
      repoCollectionProvider.select((c) => c?.getShip(fit.fit.body.shipTypeId)),
    );

    if (shipInfo == null) {
      if (isCheckoutSwitching) {
        return Layout(
          title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
          child: const FitPageSkeleton(),
        );
      }

      if (compatibilityNotice == null) {
        error("Failed to load ship info for fit $fitId: ${fit.fit.body.shipTypeId}");
      }
      return Layout(
        title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
        child: _FitPageErrorState(
          icon: Icons.warning_amber_rounded,
          title: compatibilityNotice?.title ?? context.l10n.fitPageUnavailableTitle,
          message: compatibilityNotice?.message ?? context.l10n.fitPageShipUnavailableMessage,
          details: "typeId=${fit.fit.body.shipTypeId}",
          actions: [
            FilledButton.icon(
              onPressed: ref.read(fitProvider(fitId).notifier).reload,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.fitPageRetryAction),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: Text(context.l10n.fitPageBackAction),
            ),
          ],
        ),
      );
    }

    final emulated = ref.watch(nativeEmulatedShipProvider(fitId));

    final fitWrapper = FitWrapper(
      wrapped: ref.read(fitProvider(fitId).notifier),
      fitId: fitId,
      ref: ref,
    );
    final fitContext = FitContext(
      fitId: fitId,
      fit: fit.fit,
      ship: shipInfo,
      emulated: emulated,
      fitWrapper: fitWrapper,
    );

    return Layout(
      title: context.l10n.fitPageTitle(fitName: fitMetadata.name, shipName: shipName),
      child: Stack(
        children: [
          FitDisplayColumns(fitContext: fitContext, compatibilityNotice: compatibilityNotice),
          if (showCheckoutSwitchOverlay)
            _FitCheckoutSwitchOverlay(pendingCheckoutId: overlayCheckoutId),
        ],
      ),
    );
  }
}

class _FitCheckoutSwitchOverlay extends StatelessWidget {
  const _FitCheckoutSwitchOverlay({required this.pendingCheckoutId});

  final String pendingCheckoutId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;

    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.scrim.withValues(alpha: 0.28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Material(
              color: colorScheme.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.repoLoadingTitle,
                      style: context.theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.repoLoadingDescription(checkoutId: pendingCheckoutId),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FitPageErrorState extends StatelessWidget {
  const _FitPageErrorState({
    required this.icon,
    required this.title,
    required this.message,
    this.details,
    this.actions = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String message;
  final String? details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  if (details != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      details!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: actions,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FitInteractionOptions {
  const FitInteractionOptions({
    this.allowMutations = true,
    this.allowInspect = true,
    this.allowStateToggle = true,
    this.allowFighterAbilityToggle = true,
    this.allowHpToggle = true,
  });

  static const screenshot = FitInteractionOptions(allowMutations: false, allowInspect: false);

  final bool allowMutations;
  final bool allowInspect;
  final bool allowStateToggle;
  final bool allowFighterAbilityToggle;
  final bool allowHpToggle;
}
