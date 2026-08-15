import "dart:async";

import "package:app_links/app_links.dart";
import "package:efa_fit/efa_fit.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:flutter/foundation.dart";

class NativeFitLinkIntake {
  NativeFitLinkIntake({required this.onFitLink, required this.onInternalLink});

  final void Function(Uri uri) onFitLink;
  final void Function(Uri uri) onInternalLink;

  StreamSubscription<Uri>? _subscription;

  void start() {
    if (kIsWeb) return;
    _subscription = AppLinks().uriLinkStream.listen(
      dispatch,
      onError: (Object e) => warning("App link stream error: $e"),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void dispatch(Uri uri) {
    if (parseFitLinkUri(uri) != null) {
      onFitLink(uri);
      return;
    }
    if (uri.scheme.toLowerCase() == efaScheme) {
      onInternalLink(uri);
      return;
    }
    debug("Unhandled external link: ${uri.scheme}://${uri.host}${uri.path}");
  }
}
