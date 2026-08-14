import "dart:async";

import "package:app_links/app_links.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/fit_link/fit_link_uri.dart";
import "package:flutter/foundation.dart";

class NativeFitLinkIntake {
  NativeFitLinkIntake({required this.onFitLink, required this.onInternalLink});

  final void Function(Uri uri) onFitLink;
  final void Function(Uri uri) onInternalLink;

  StreamSubscription<Uri>? _subscription;

  Future<void> start() async {
    if (kIsWeb) return;
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) dispatch(initial);
    } on Object catch (e) {
      warning("Failed to read initial app link: $e");
    }
    _subscription = appLinks.uriLinkStream.listen(
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
