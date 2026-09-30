import "package:efa_fit/efa_fit.dart";
import "package:efa_proto/fit.pb.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_client.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_server.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/utils/native_convert.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

enum KillmailImportErrorCode {
  emptyInput,
  invalidUrl,
  notFound,
  fetchBlocked,
  fetchFailed,
  invalidKillmail,
  unavailableShip,
  unavailableData,
}

class KillmailImportException implements Exception {
  const KillmailImportException(this.code, {this.detail});

  final KillmailImportErrorCode code;
  final String? detail;

  @override
  String toString() => "KillmailImportException($code, detail: $detail)";
}

class KillmailImporter {
  const KillmailImporter(this.ref);

  final WidgetRef ref;

  /// Imports the killmail behind a killboard URL or bare killmail ID. Bare
  /// IDs require [server]; URLs carry their server in the host.
  Future<FitMetadata> importFromUrl(String input, {KillboardServer? server}) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw const KillmailImportException(KillmailImportErrorCode.emptyInput);
    }

    final fromUrl = KillboardClient.parseKillUrl(text);
    final (resolvedServer, killmailId) = switch ((fromUrl, server, int.tryParse(text))) {
      (final parsed?, _, _) => parsed,
      (null, final selected?, final bareId?) => (selected, bareId),
      _ => throw const KillmailImportException(KillmailImportErrorCode.invalidUrl),
    };

    final client = KillboardClient();
    final Killmail killmail;
    try {
      killmail = await client.fetchKillmail(resolvedServer, killmailId);
    } on KillboardFetchException catch (error) {
      throw switch (error.code) {
        KillboardFetchErrorCode.notFound => KillmailImportException(
          KillmailImportErrorCode.notFound,
          detail: error.detail,
        ),
        KillboardFetchErrorCode.blocked => const KillmailImportException(
          KillmailImportErrorCode.fetchBlocked,
        ),
        KillboardFetchErrorCode.fetchFailed => const KillmailImportException(
          KillmailImportErrorCode.fetchFailed,
        ),
        KillboardFetchErrorCode.invalidResponse => const KillmailImportException(
          KillmailImportErrorCode.invalidKillmail,
        ),
      };
    } finally {
      client.dispose();
    }

    return _import(killmailToFit(killmail), sourceUri: resolvedServer.killmailPageUri(killmailId));
  }

  /// Imports a killmail from pasted ESI/zKillboard JSON (fallback for when
  /// the killboard API cannot be reached, e.g. behind a WAF challenge).
  Future<FitMetadata> importFromJson(String input) async {
    final text = input.trim();
    if (text.isEmpty) {
      throw const KillmailImportException(KillmailImportErrorCode.emptyInput);
    }
    final Killmail killmail;
    try {
      killmail = parseKillmailJson(text);
    } on KillmailFormatException {
      throw const KillmailImportException(KillmailImportErrorCode.invalidKillmail);
    }
    return _import(killmailToFit(killmail));
  }

  Future<FitMetadata> _import(KillmailFit parsed, {Uri? sourceUri}) async {
    final collection = ref.read(repoCollectionProvider);
    if (collection == null) {
      throw const KillmailImportException(KillmailImportErrorCode.unavailableData);
    }
    final ship = collection.getShip(parsed.shipTypeId);
    if (ship == null) {
      throw KillmailImportException(
        KillmailImportErrorCode.unavailableShip,
        detail: "${parsed.shipTypeId}",
      );
    }

    var fit = FitStorage.empty(
      FitMetadata(
        fitId: "import-preview",
        shipTypeId: parsed.shipTypeId,
        name: "KM ${parsed.killmailId}",
        lastModified: 0,
        description: sourceUri?.toString() ?? "",
        checkoutRef: const CheckoutRef(checkoutId: "", serverId: ""),
      ),
      ship,
    );

    for (final rack in KillmailRack.values) {
      final slots = parsed.racks[rack];
      if (slots == null) continue;
      for (final entry in slots.entries) {
        fit = _setModuleAt(
          fit,
          rack,
          entry.key,
          FitModuleItem(
            itemId: FitStorageItemId.item(id: entry.value),
            // Killmails do not record module state; default like the app's
            // own equip paths: activatable modules come in active,
            // passive-only ones online.
            state: _defaultModuleState(collection.slots, rack, entry.value),
            charge: const Option.none(),
          ),
        );
      }
    }

    fit = fit.copyWith(
      body: fit.body.copyWith(
        drones: [
          for (final drone in parsed.drones)
            FitDroneItem(
              itemId: FitStorageItemId.item(id: drone.typeId),
              state: FitItemState.passive,
              quantity: drone.quantity,
            ),
        ].toIList(),
        fighters: [
          for (final (groupIndex, fighter) in parsed.fighters.indexed)
            FitFighterItem(
              itemId: FitStorageItemId.item(id: fighter.typeId),
              groupId: groupIndex,
              quantity: fighter.quantity,
              fighterAbility: 0,
            ),
        ].toIList(),
      ),
    );

    return ref.read(fitManagerProvider.notifier).importFit(fit);
  }

  FitItemState _defaultModuleState(Slots slotsInfo, KillmailRack rack, int typeId) {
    final maxState = switch (rack) {
      KillmailRack.high => slotsInfo.highSlots[typeId]?.maxState,
      KillmailRack.medium => slotsInfo.mediumSlots[typeId]?.maxState,
      KillmailRack.low => slotsInfo.lowSlots[typeId]?.maxState,
      KillmailRack.rig => slotsInfo.rigSlots[typeId]?.maxState,
      KillmailRack.subsystem => slotsInfo.subsystemSlots[typeId]?.maxState,
      KillmailRack.service => slotsInfo.serviceSlots[typeId]?.maxState,
    };
    return (maxState?.dartImpl ?? FitItemState.online).limitToActive;
  }

  FitStorage _setModuleAt(FitStorage fit, KillmailRack rack, int index, FitModuleItem module) {
    // Flags beyond the ship's slot count (e.g. out-of-range ESI flags) are
    // dropped instead of failing the whole import.
    IList<Option<FitModuleItem>> updateList(IList<Option<FitModuleItem>> slots) {
      if (index < 0 || index >= slots.length) return slots;
      return slots.replace(index, some(module));
    }

    return switch (rack) {
      KillmailRack.low => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(low: updateList(fit.body.slots.low)),
        ),
      ),
      KillmailRack.medium => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(medium: updateList(fit.body.slots.medium)),
        ),
      ),
      KillmailRack.high => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(high: updateList(fit.body.slots.high)),
        ),
      ),
      KillmailRack.rig => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(rig: updateList(fit.body.slots.rig)),
        ),
      ),
      KillmailRack.subsystem => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(subsystem: updateList(fit.body.slots.subsystem)),
        ),
      ),
      KillmailRack.service => fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(service: updateList(fit.body.slots.service)),
        ),
      ),
    };
  }
}
