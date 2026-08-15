import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class FitLinkImporter {
  const FitLinkImporter(this.ref);

  final Ref ref;

  Future<FitMetadata> import(Uri uri) {
    final parsed = parseFitLinkUri(uri);
    return _importParsed(uri, parsed);
  }

  Future<FitMetadata> importBootUri(Uri uri) {
    final parsed = parseFitLinkBootUri(uri);
    return _importParsed(uri, parsed);
  }

  Future<FitMetadata> _importParsed(Uri uri, FitLinkParseResult? parsed) async {
    if (parsed == null) {
      throw FitLinkNotFoundException(uri);
    }
    final fit = parsePayload(parsed.payload);
    return ref.read(fitManagerProvider.notifier).importFit(fit);
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
