import "package:efa_acl/efa_acl.dart";
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
final Provider<void Function()> platformAuthRequiredHandlerProvider = Provider((Ref ref) => () {});

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
  final (:clientId, :clientSecret) = await store.readCfAccessServiceToken();
  return PlatformSession(
    origin: origin,
    store: store,
    // The platform API is dynamic and interactive (feed, comments, writes):
    // bypass the shared HTTP response cache, whose store failures surfaced
    // as request failures and whose entries served stale, server-side-gone
    // posts.
    dioFactory: () => createRemoteDio(useCache: false),
    cfAccessClientId: clientId.isEmpty ? null : clientId,
    cfAccessClientSecret: clientSecret.isEmpty ? null : clientSecret,
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

/// The signed-in account's server-side record: identity plus the placeholder
/// ACL roles and their resolved permission tokens; null when signed out.
@riverpodSingleton
Future<PlatformAccountInfo?> platformAccountInfo(Ref ref) async {
  final identity = await ref.watch(platformIdentityProvider.future);
  if (identity == null) return null;
  final session = await ref.watch(platformSessionProvider.future);
  return session.accountInfo();
}

/// The signed-in account's ACL token set, resolved from its placeholder
/// permission roles (see `packages/efa_acl`); empty while signed out.
@riverpodSingleton
Future<Acl> accountAcl(Ref ref) async {
  final info = await ref.watch(platformAccountInfoProvider.future);
  if (info == null) return Acl(const {});
  return aclForRoles(info.roles);
}
