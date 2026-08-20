import "package:efa_fit/efa_fit.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/fit_link/state_import.dart";
import "package:eve_fit_assistant/features/platform/platform_api.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FitLinkImporter {
  const FitLinkImporter(this.ref);

  final Ref ref;

  Future<FitMetadata> import(Uri uri) => _importParsed(uri, parseFitLinkUri(uri));

  Future<FitMetadata> importBootUri(Uri uri) => _importParsed(uri, parseFitLinkBootUri(uri));

  Future<FitMetadata> _importParsed(Uri uri, FitLinkParseResult? parsed) async => switch (parsed) {
    FitLinkRaw(:final payload) => _importRaw(payload),
    FitLinkRegistered(:final fitHash) => _importRegistered(uri, fitHash),
    null => throw FitLinkNotFoundException(uri),
  };

  Future<FitMetadata> _importRaw(String payload) async {
    final fit = parsePayload(payload);
    return ref.read(fitManagerProvider.notifier).importFit(fit);
  }

  /// Imports a registered fit link: the URL carries only the fit hash, so the
  /// canonical state is retrieved from the platform API and converted back
  /// into a [FitStorage] (see `fitStateToStorage`).
  Future<FitMetadata> _importRegistered(Uri uri, String fitHash) async {
    final api = ref.read(platformApiClientProvider);
    final state = await api.getFitState(fitHash);
    if (state == null) {
      throw FitLinkNotFoundException(uri);
    }
    final header = (await _tryGetSnapshot(api, fitHash))?.header;
    final characterId = await _resolveCharacterId(state);
    final converted = fitStateToStorage(state, characterId: characterId);
    final metadata = FitMetadata(
      // Placeholders; FitManager.importFit assigns the id, stamps the active
      // checkout, and refreshes the timestamps.
      fitId: "",
      shipTypeId: state.shipTypeId,
      name: header?.fitName ?? "",
      lastModified: DateTime.now().millisecondsSinceEpoch,
      description: header?.description ?? "",
      checkoutRef: const CheckoutRef(checkoutId: "", serverId: ""),
    );
    return ref
        .read(fitManagerProvider.notifier)
        .importFit(
          FitStorage(
            metadata: metadata,
            body: converted.body,
            dynamicRegistry: converted.dynamicRegistry,
          ),
        );
  }

  /// The snapshot carries the display metadata (name, description) the state
  /// lacks; the import still proceeds when it cannot be retrieved.
  Future<FitSnapshot?> _tryGetSnapshot(PlatformApiClient api, String fitHash) async {
    try {
      return await api.getFitSnapshot(fitHash);
    } on Object catch (e) {
      warning("Registered fit import: snapshot metadata unavailable for $fitHash: $e");
      return null;
    }
  }

  /// Registered fits carry an explicit skill map instead of a local character
  /// reference. Built-in profiles map back to their predefined ids (by the
  /// display-name convention of `FitUploadRequestBuilder`); a character id
  /// that already exists locally is reused; anything else is recreated as a
  /// new custom character from the uploaded skills.
  Future<String> _resolveCharacterId(FitState state) async {
    final character = state.hasCharacter() ? state.character : null;
    final characterId = character != null && character.hasCharacterId()
        ? character.characterId
        : "";
    if (CharacterRegistryManager.isBuiltInCharacterId(characterId)) return characterId;
    if (characterId.isNotEmpty &&
        ref.read(characterRegistryManagerProvider).characters.containsKey(characterId)) {
      return characterId;
    }
    if (characterId.isEmpty) {
      final builtin = switch (character?.names["en"]) {
        "All 5" => predefinedMaxCharacterId,
        "All 0" => predefinedZeroCharacterId,
        "Alpha Max" => predefinedAlphaMaxCharacterId,
        _ => null,
      };
      if (builtin != null) return builtin;
    }
    final name = character?.names["en"];
    final created = await ref
        .read(characterRegistryManagerProvider.notifier)
        .importCharacter(
          name: name == null || name.trim().isEmpty ? "Imported Character" : name.trim(),
          skills: {for (final skill in state.skills) skill.typeId: skill.level},
        );
    info("Registered fit import: created character ${created.characterId} (${created.name})");
    return created.characterId;
  }

  FitStorage parsePayload(String payload) {
    try {
      final decoded = decodeEfaFitLinkPayload(payload);
      return decodeNativeFitPayload(decoded).fit;
    } on EfaFitFormatException catch (e) {
      warning("Fit link rejected: ${e.code} ${_summarizePayload(payload)}");
      rethrow;
    } on Object {
      warning(
        "Fit link rejected: ${EfaFitFormatErrorCode.invalidJson} ${_summarizePayload(payload)}",
      );
      throw const EfaFitFormatException(EfaFitFormatErrorCode.invalidJson);
    }
  }

  static String _summarizePayload(String payload) {
    const headLength = 32;
    final head = payload.length <= headLength ? payload : payload.substring(0, headLength);
    return "(length: ${payload.length}, head: $head)";
  }
}
