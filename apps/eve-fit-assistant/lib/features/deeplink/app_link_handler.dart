import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/deeplink/app_link.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch_dialog.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

final appLinkHandlerProvider = Provider<AppLinkHandler>((Ref ref) => const AppLinkHandler());

/// Action name for `efa://action/switch-channel`: opens the data channel
/// switch dialog.
const String appLinkActionSwitchChannel = "switch-channel";

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
  /// paths matching no route show user feedback and are logged. Action links
  /// (`efa://action/...`) run their registered behavior. External links open
  /// in the external browser.
  Future<void> open(BuildContext context, String rawUrl, {String basePath = "/"}) async {
    final link = parseAppLink(rawUrl, basePath: basePath);
    if (link == null || !context.mounted) return;

    switch (link) {
      case InternalAppLink(path: final path):
        if (context.router.matcher.match(path) == null) {
          debug("AppLink: no route matched $path");
          _notifyInvalid(context);
          return;
        }
        await context.router.pushPath(path);
      case ActionAppLink(name: final name):
        await _runAction(context, name);
      case ExternalAppLink(uri: final uri):
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _runAction(BuildContext context, String name) async {
    switch (name) {
      case appLinkActionSwitchChannel:
        await showChannelSwitchDialog(context);
      default:
        debug("AppLink: unknown action $name");
        _notifyInvalid(context);
    }
  }

  void _notifyInvalid(BuildContext context) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.appLinkInvalid)));
  }
}
