import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/deeplink/app_link.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

final appLinkHandlerProvider = Provider<AppLinkHandler>((Ref ref) => const AppLinkHandler());

/// Dispatches content links resolved by [parseAppLink].
///
/// All in-app navigation triggered from content (markdown links today,
/// OS-level deeplinks with redirect handling in the future) should go
/// through this handler so the behavior stays consistent.
class AppLinkHandler {
  const AppLinkHandler();

  /// Open [rawUrl] found in app content.
  ///
  /// In-app links (`efa://...`, absolute paths, and paths relative to
  /// [basePath]) are validated against the route table before being pushed;
  /// paths matching no route show user feedback and are logged. External
  /// links open in the external browser.
  Future<void> open(BuildContext context, String rawUrl, {String basePath = "/"}) async {
    final link = parseAppLink(rawUrl, basePath: basePath);
    if (link == null || !context.mounted) return;

    switch (link) {
      case InternalAppLink(path: final path):
        if (context.router.matcher.match(path) == null) {
          debug("AppLink: no route matched $path");
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(context.l10n.appLinkInvalid)));
          return;
        }
        await context.router.pushPath(path);
      case ExternalAppLink(uri: final uri):
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
