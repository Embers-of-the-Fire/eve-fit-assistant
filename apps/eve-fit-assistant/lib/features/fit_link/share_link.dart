import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";

class FitShareLinkBuilder {
  const FitShareLinkBuilder();

  String? buildShareUrl(FitStorage fit) {
    final payload = encodeEfaFitLinkPayload(encodeNativeFitPayload(fit));
    if (payload.length > maxEfaFitLinkEncodedPayloadChars) return null;
    return buildFitLinkShareUrl(payload);
  }
}
