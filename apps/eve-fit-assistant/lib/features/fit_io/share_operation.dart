import "dart:convert";

import "package:efa_acl/efa_acl.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_io/snapshot_upload_api.dart";
import "package:eve_fit_assistant/features/fit_io/upload_request.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

/// Injectable seam for opening the shared post page in the browser, so tests
/// can intercept the redirect.
final fitShareUrlLauncherProvider = Provider<Future<bool> Function(Uri)>(
  (Ref ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);

/// Whether the current account may publish fits to the platform. The platform
/// API enforces `post:create` for real; this is the client-side gate for the
/// share entry points. Fail-closed while the identity/ACL resolve, and stale
/// values kept during refresh or after an error are ignored (`hasValue` stays
/// true in both cases).
final fitShareEligibilityProvider = Provider<bool>((Ref ref) {
  final signedIn = ref.watch(platformIdentityProvider.select((identity) => identity.value != null));
  if (!signedIn) return false;
  final accountAcl = ref.watch(accountAclProvider);
  if (accountAcl.isLoading || accountAcl.hasError) return false;
  return accountAcl.value?.canPostCreate() ?? false;
});

/// The dedicated "share" operation: uploads the fit to the platform and
/// returns the resulting [FitPostSubmitResult]. The post page is only opened
/// on explicit user request ([openPost]), because the site may still be
/// processing the upload right after submission.
class FitShareOperation {
  const FitShareOperation();

  /// Uploads the fit via [fitSnapshotUploadFnProvider]. Does not open the
  /// post page; callers decide when to offer that action.
  ///
  /// [allowLatestSnapshotFallback] is the user's consent to reproduce the fit
  /// with the server's latest completed snapshot when the app's data snapshot
  /// is not registered on the platform.
  Future<FitPostSubmitResult> share(
    WidgetRef ref, {
    required String fitId,
    required FitStorage fit,
    bool allowLatestSnapshotFallback = false,
  }) async => ref.read(fitSnapshotUploadFnProvider)(
    ref,
    fitId: fitId,
    fit: fit,
    allowLatestSnapshotFallback: allowLatestSnapshotFallback,
  );

  /// Opens a post page URL through [fitShareUrlLauncherProvider]. Launcher
  /// failures (a `false` return or a thrown exception) are non-fatal: they
  /// are logged and the caller still receives the upload result.
  Future<void> openPost(WidgetRef ref, String postUrl) async {
    bool opened;
    try {
      opened = await ref.read(fitShareUrlLauncherProvider)(Uri.parse(postUrl));
    } catch (error, stackTrace) {
      warning("Fit share: unable to open the post page $postUrl: $error", stackTrace: stackTrace);
      return;
    }
    if (!opened) {
      warning("Fit share: unable to open the post page $postUrl");
    }
  }
}

/// Maps a share failure to a user-facing message.
String describeFitShareError(AppLocalizations l10n, Object error) => switch (error) {
  FitUploadNotReadyException() => l10n.fitShareErrorDataNotReady,
  // The global onAuthRequired handler already pushed the login route.
  PlatformAuthRequiredException() => l10n.fitShareErrorUnauthorized,
  final FitUploadException e => switch (e.code) {
    FitUploadErrorCode.unauthorized => l10n.fitShareErrorUnauthorized,
    FitUploadErrorCode.forbidden => l10n.fitShareErrorForbidden,
    FitUploadErrorCode.snapshotIncomplete => l10n.fitShareErrorSnapshotIncomplete,
    FitUploadErrorCode.validationFailed => l10n.fitShareErrorValidation(
      message: _describeUploadFailure(e),
    ),
    FitUploadErrorCode.unknownType => l10n.fitShareErrorUnknownType(message: e.message ?? ""),
    FitUploadErrorCode.network => l10n.fitShareErrorNetwork,
    _ => l10n.fitShareErrorGeneric,
  },
  _ => l10n.fitShareErrorGeneric,
};

String _describeUploadFailure(FitUploadException e) => [
  if (e.message case final message? when message.isNotEmpty) message,
  if (e.issues != null) jsonEncode(e.issues),
].join(" — ");

/// Logging for share failures, mirroring the previous dialog-side behavior.
void logFitShareFailure(Object error, StackTrace stackTrace) {
  switch (error) {
    case FitUploadNotReadyException():
      warning("Fit share aborted: data repository is not ready");
    case PlatformAuthRequiredException():
      warning("Fit share aborted: platform sign-in required");
    case final FitUploadException e:
      if (e.code == FitUploadErrorCode.unexpected) {
        fatal("Fit share failed unexpectedly", error: e, stackTrace: stackTrace);
      } else {
        warning(
          "Fit share rejected (${e.code.name})${e.message == null ? "" : ": ${e.message}"}"
          "${e.issues == null ? "" : "\nissues: ${jsonEncode(e.issues)}"}",
        );
      }
    default:
      fatal("Fit share failed with an unexpected error", error: error, stackTrace: stackTrace);
  }
}
