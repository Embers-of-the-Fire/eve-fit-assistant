import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/features/account/session_store.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Navigation performed when the platform session reports that interactive
/// authentication is required (the session was rejected server-side).
/// Overridden in `main.dart` with a router push to the login page; defaults
/// to a no-op so tests and non-router contexts can use the session directly.
final platformAuthRequiredHandlerProvider = Provider<void Function()>((Ref ref) => () {});

/// The single platform API session: all account flows and platform reads go
/// through it, and token handling never crosses its boundary.
///
/// Rebuilt when the developer-only origin override changes; the new instance
/// re-runs the cold-start rotation against the same stored session.
@riverpodSingleton
Future<PlatformSession> platformSession(Ref ref) async {
  final (:developerMode, :customOrigin) = ref.watch(
    appSettingServiceProvider.select<({bool developerMode, String customOrigin})>(
      (s) => (developerMode: s.developerMode, customOrigin: s.account.customOrigin),
    ),
  );
  final custom = customOrigin.trim();
  // The custom origin is a developer-only override: use it only while
  // developer mode is on, and never clear the stored value.
  final origin = developerMode && custom.isNotEmpty ? custom : platformApiProductionOrigin;
  final store = ref.watch(securePlatformSessionStoreProvider);
  final cfAccessToken = await store.readCfAccessToken();
  return PlatformSession(
    origin: origin,
    store: store,
    dioFactory: createRemoteDio,
    cfAccessToken: cfAccessToken.isEmpty ? null : cfAccessToken,
    emailLocale: () => ref.read(localeProvider).name,
    onAuthRequired: () => ref.read(platformAuthRequiredHandlerProvider)(),
  );
}

/// The signed-in platform identity, bridged from the session's stream; null
/// when signed out.
@riverpodSingleton
Stream<PlatformIdentity?> platformIdentity(Ref ref) async* {
  final session = await ref.watch(platformSessionProvider.future);
  yield* session.identity;
}
