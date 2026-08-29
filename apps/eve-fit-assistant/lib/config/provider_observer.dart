import "package:eve_fit_assistant/config/logger.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Logs provider failures that Riverpod captures into [AsyncError].
///
/// Provider errors never reach `PlatformDispatcher.onError` (Riverpod catches
/// them), and async UIs typically surface only a generic localized message,
/// so without this observer a failing provider leaves no trace in the logs.
final class LoggingProviderObserver extends ProviderObserver {
  const LoggingProviderObserver();

  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    warning("Provider ${context.provider} failed: $error", stackTrace: stackTrace);
  }
}
