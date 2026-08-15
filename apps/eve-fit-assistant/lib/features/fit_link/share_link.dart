import "package:eve_fit_assistant/features/fit_link/codec.dart";
import "package:eve_fit_assistant/features/fit_link/fit_link_uri.dart" as fit_link_uri;
import "package:eve_fit_assistant/storage/fit/schema.dart";

class FitShareLinkBuilder {
  const FitShareLinkBuilder();

  String? buildShareUrl(FitStorage fit) {
    final payload = encodeFitLinkPayload(fit);
    if (payload.length > maxFitLinkEncodedPayloadChars) return null;
    return fit_link_uri.buildShareUrl(payload);
  }
}
