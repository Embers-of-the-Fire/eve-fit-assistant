import "dart:convert";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/agent_resource_db.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "fit_context.g.dart";

/// The fit currently attached to the chat session.
///
/// Set by the fit page while a fit is open, so the chatbot's fit tools
/// operate on the fit the user is looking at.
@riverpodSingleton
class ChatAttachedFitId extends _$ChatAttachedFitId {
  @override
  String? build() => null;

  void attach(String fitId) {
    if (state != fitId) state = fitId;
  }

  /// Detach only when [fitId] is still the attached one — another fit page
  /// may have taken over between this page's disposal and this call.
  void detach(String fitId) {
    if (state == fitId) state = null;
  }
}

/// Attach the fitting engine to [session], exposing the fit tools. Returns
/// the engine instance that was attached, or `null` when the engine is not
/// initialized yet.
native_server.FitEngine? attachFitEngine(Ref ref, native_chat.ChatSession session) {
  final engine = ref.read(nativeFitEngineServiceProvider).engineOrNull;
  if (engine == null) return null;
  session.setFitEngine(engine: engine.shareData());
  return engine;
}

/// Push the dogma-attribute name table (attribute id → attribute name) into
/// [session], used by the `get_attr`/`get_item` tools for name resolution.
void attachAttributeNames(Ref ref, native_chat.ChatSession session) {
  final collection = ref.read(repoCollectionProvider);
  if (collection == null) return;
  session.setAttributeNames(
    names: {for (final entry in collection.dogmaAttributes.entries) entry.key: entry.value.name},
  );
}

/// Push the fit attached via [chatAttachedFitIdProvider] into [session].
///
/// Silently no-ops (leaving any previously attached context in place) while
/// prerequisites are still loading; clears the context when no fit is
/// attached at all.
Future<void> pushAttachedFit(Ref ref, native_chat.ChatSession session) async {
  final fitId = ref.read(chatAttachedFitIdProvider);
  if (fitId == null) {
    session.clearFitContext();
    return;
  }

  final fitState = ref.read(fitProvider(fitId));
  if (!fitState.isInitialized) return;
  final fit = fitState.fit;

  final collection = ref.read(repoCollectionProvider);
  if (collection == null) return;

  final skills = await ref
      .read(characterRegistryManagerProvider.notifier)
      .resolveCharacterSkills(fit.body.characterId, collection.getSkillTypeIds());
  final nativeFit = convertToNative(fit, characterSkills: skills);

  final locale = ref.read(localeProvider).name;
  final localization = await ref.read(localizationDbServiceProvider.future);
  if (localization == null) return;
  final names = await localization.localizedNames({
    ...referencedTypeIds(fit),
    ...skills.keys,
  }, locale);

  session.setFitContext(name: fit.metadata.name, fit: nativeFit, names: names);
  debug("chat: attached fit ${fit.metadata.fitId} to chat session");
}

/// Every static type id referenced by [fit] (ship, modules, charges, drones,
/// fighters, implants, boosters), with dynamic (mutated) items resolved to
/// their mutated type id.
Set<int> referencedTypeIds(FitStorage fit) {
  int? resolve(FitStorageItemId itemId) => itemId.when(
    item: (id) => id,
    dynamic: (dynamicId) => fit.dynamicRegistry.dynamicItems[dynamicId]?.typeId,
  );

  final ids = <int>{fit.body.shipTypeId};
  for (final slots in [
    fit.body.slots.high,
    fit.body.slots.medium,
    fit.body.slots.low,
    fit.body.slots.rig,
    fit.body.slots.subsystem,
    fit.body.slots.service,
  ]) {
    for (final module in slots.filterNone()) {
      final typeId = resolve(module.itemId);
      if (typeId != null) ids.add(typeId);
      final charge = module.charge.toNullable();
      if (charge != null) ids.add(charge.typeId);
    }
  }
  for (final drone in fit.body.drones) {
    final typeId = resolve(drone.itemId);
    if (typeId != null) ids.add(typeId);
  }
  for (final fighter in fit.body.fighters) {
    final typeId = resolve(fighter.itemId);
    if (typeId != null) ids.add(typeId);
  }
  for (final implant in fit.body.implants) {
    final typeId = resolve(implant.itemId);
    if (typeId != null) ids.add(typeId);
  }
  for (final booster in fit.body.boosters) {
    final typeId = resolve(booster.itemId);
    if (typeId != null) ids.add(typeId);
  }
  return ids;
}

/// Register the app-state callbacks backing the `search_items`,
/// `list_user_fits`, and `load_fit` chat tools on [session].
Future<void> registerFitCallbacks(Ref ref, native_chat.ChatSession session) async {
  try {
    session.setFitCallbacks(
      searchItems: (query, language, kind) => _searchItems(ref, query, language, kind),
      listFits: () => _listFits(ref),
      loadFit: (fitId) => _loadFit(ref, fitId),
    );
  } on Object catch (e, st) {
    warning("chat: failed to register fit callbacks: $e", stackTrace: st);
  }
}

Future<String> _searchItems(Ref ref, String query, String? language, String? kind) async {
  final AgentSearchKind? parsedKind;
  if (kind == null || kind.trim().isEmpty) {
    parsedKind = null;
  } else {
    parsedKind = AgentSearchKind.parse(kind);
    if (parsedKind == null) {
      return jsonEncode({
        "error":
            "unknown kind `$kind`; expected one of: ship, module, charge, drone, fighter, implant, booster",
      });
    }
  }
  // Hard dependency, but Dart exceptions cannot cross the FRB callback
  // boundary (the generated binding panics on them), so an unavailable
  // database is reported to the model as an error payload instead.
  final AgentResourceDbService agentDb;
  try {
    agentDb = await ref.read(agentResourceDbServiceProvider.future);
  } on Object catch (e, st) {
    warning("chat: search_items database unavailable: $e", stackTrace: st);
    return jsonEncode({"error": "item search is unavailable: $e"});
  }
  try {
    final locale = _searchLocale(ref, language);
    final hits = await agentDb.searchTypes(query, locale, kind: parsedKind);
    final results = <Map<String, Object?>>[
      for (final hit in hits)
        {
          "type_id": hit.typeId,
          "name": hit.name,
          "group_id": hit.groupId,
          "category_id": hit.categoryId,
          if (hit.slotIndex != null) "slot_index": hit.slotIndex,
          if (hit.slotKind != null) "slot_kind": hit.slotKind,
        },
    ];
    return jsonEncode(results);
  } on Object catch (e, st) {
    warning("chat: search_items failed: $e", stackTrace: st);
    return "[]";
  }
}

/// Resolves the localization to search item names in: an explicit [language]
/// tag from the model (zh* → zh, anything else → en, mirroring the prompt
/// language resolution), or the app's display language when omitted/blank.
String _searchLocale(Ref ref, String? language) {
  final tag = language?.trim().toLowerCase() ?? "";
  if (tag.isEmpty) return ref.read(localeProvider).name;
  return tag.startsWith("zh") ? Locale.zh.name : Locale.en.name;
}

Future<String> _listFits(Ref ref) async {
  try {
    final registry = ref.read(fitRegistryManagerProvider);
    final fits = [
      for (final meta in registry.fits.values)
        {
          "fit_id": meta.fitId,
          "name": meta.name,
          "ship_type_id": meta.shipTypeId,
          "last_modified": meta.lastModified,
        },
    ];
    return jsonEncode(fits);
  } on Object catch (e, st) {
    warning("chat: list_user_fits failed: $e", stackTrace: st);
    return "[]";
  }
}

Future<String> _loadFit(Ref ref, String fitId) async {
  try {
    final registry = ref.read(fitRegistryManagerProvider);
    if (!registry.fits.containsKey(fitId)) {
      return jsonEncode({"error": "fit $fitId not found"});
    }

    final fit = await _readFitFromDisk(ref, fitId);
    if (fit == null) {
      return jsonEncode({"error": "fit $fitId could not be loaded"});
    }

    // Make the loaded fit the attached one, so the app UI and subsequent
    // turns follow it.
    ref.read(chatAttachedFitIdProvider.notifier).attach(fitId);

    final collection = ref.read(repoCollectionProvider);
    if (collection == null) {
      return jsonEncode({"error": "static data is still loading"});
    }
    final skills = await ref
        .read(characterRegistryManagerProvider.notifier)
        .resolveCharacterSkills(fit.body.characterId, collection.getSkillTypeIds());

    final locale = ref.read(localeProvider).name;
    final localization = await ref.read(localizationDbServiceProvider.future);
    final names = localization == null
        ? const <int, String>{}
        : await localization.localizedNames({...referencedTypeIds(fit), ...skills.keys}, locale);

    return jsonEncode(encodeFitPayload(fit, characterSkills: skills, names: names));
  } on Object catch (e, st) {
    warning("chat: load_fit failed for $fitId: $e", stackTrace: st);
    return jsonEncode({"error": "$e"});
  }
}

/// Reads and decodes a fit directly from the fits document store, bypassing
/// the (auto-dispose, view-scoped) `fitProvider` so any saved fit can be
/// loaded on demand.
Future<FitStorage?> _readFitFromDisk(Ref ref, String fitId) async {
  try {
    final store = ref.read(fitsDocStoreProvider);
    final text = await store.read("$fitId.json");
    if (text == null) return null;
    final decoded = decodeFitStorage(jsonDecode(text) as Map<String, dynamic>);
    return pruneDynamicRegistry(decoded.fit);
  } on Object catch (e, st) {
    warning("chat: failed to read fit $fitId from disk: $e", stackTrace: st);
    return null;
  }
}

/// Serialize [fitStorage] into the JSON payload expected by the chat crate's
/// `schema::FitPayload` (mirrors `convertToNative`, but as JSON so it can
/// cross the `load_fit` callback boundary).
Map<String, Object?> encodeFitPayload(
  FitStorage fitStorage, {
  required Map<int, int> characterSkills,
  required Map<int, String> names,
}) {
  final fit = convertFitBodyToNative(fitStorage);
  final validDynamicIds = collectReferencedDynamicItemIds(
    fitStorage,
  ).intersection(fitStorage.dynamicRegistry.dynamicItems.keys.toSet());

  return {
    "name": fitStorage.metadata.name,
    "names": {for (final e in names.entries) "${e.key}": e.value},
    "fit": _encodeNativeFit(fit),
    "skills": {for (final e in characterSkills.entries) "${e.key}": e.value},
    "dynamic_items": {
      for (final e in fitStorage.dynamicRegistry.dynamicItems.entries)
        if (validDynamicIds.contains(e.key))
          "${e.key}": {
            "base_type": e.value.originTypeId,
            "dynamic_attributes": {
              for (final a in e.value.dynamicAttributes.unlock.entries) "${a.key}": a.value,
            },
          },
    },
  };
}

Map<String, Object?> _encodeNativeFit(native_storage.Fit fit) => {
  "ship_type_id": fit.shipTypeId,
  "damage_profile": {
    "em": fit.damageProfile.em,
    "explosive": fit.damageProfile.explosive,
    "kinetic": fit.damageProfile.kinetic,
    "thermal": fit.damageProfile.thermal,
  },
  "modules": [for (final m in fit.modules) _encodeNativeModule(m)],
  "drones": [
    for (final d in fit.drones)
      {"type_id": d.typeId, "group_id": d.groupId, "state": _stateName(d.state)},
  ],
  "fighters": [
    for (final f in fit.fighters)
      {"type_id": f.typeId, "group_id": f.groupId, "ability": f.ability},
  ],
  "implants": [
    for (final i in fit.implants) {"type_id": i.typeId, "index": i.index},
  ],
  "boosters": [
    for (final b in fit.boosters) {"type_id": b.typeId, "index": b.index},
  ],
};

Map<String, Object?> _encodeNativeModule(native_storage.Module m) => {
  "item_id": m.itemId.when(item: (id) => {"item": id}, dynamic_: (id) => {"dynamic": id}),
  "slot": {"slot_type": _slotTypeName(m.slot.slotType), "index": m.slot.index},
  "state": _stateName(m.state),
  if (m.charge case final charge?) "charge": {"type_id": charge.typeId},
};

String _stateName(native_storage.State state) => switch (state) {
  native_storage.State.passive => "passive",
  native_storage.State.online => "online",
  native_storage.State.active => "active",
  native_storage.State.overload => "overload",
};

String _slotTypeName(native_storage.SlotType slotType) => switch (slotType) {
  native_storage.SlotType.high => "high",
  native_storage.SlotType.medium => "medium",
  native_storage.SlotType.low => "low",
  native_storage.SlotType.rig => "rig",
  native_storage.SlotType.subSystem => "subsystem",
  native_storage.SlotType.service => "service",
  native_storage.SlotType.tacticalMode => "tactical_mode",
};
