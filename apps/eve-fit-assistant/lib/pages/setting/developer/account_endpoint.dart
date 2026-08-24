part of "page.dart";

/// Developer-only tiles for pointing the platform account client at the
/// preview deployment and for supplying the Cloudflare Access service token
/// that deployment requires. Hardcoded English per the dev-only localization
/// rule.
class AccountApiEndpointTile extends ConsumerWidget {
  const AccountApiEndpointTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customOrigin = ref.watch(appSettingServiceProvider.select((s) => s.account.customOrigin));
    return ListTile(
      leading: const Icon(Icons.alternate_email_outlined),
      title: const Text("Account API endpoint"),
      subtitle: Text(
        customOrigin.trim().isEmpty
            ? "Production ($platformApiProductionOrigin)"
            : "Custom: ${customOrigin.trim()}",
      ),
      onTap: () => unawaited(_editEndpoint(context, ref)),
    );
  }

  Future<void> _editEndpoint(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(appSettingServiceProvider).account.customOrigin,
    );
    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Account API endpoint"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  hintText: "https://efa-platform-api-preview.<subdomain>.workers.dev",
                  helperText: "Leave empty for production ($platformApiProductionOrigin)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "The preview environment is protected by Cloudflare Access: "
                "requests without a valid service token (below) get "
                "the Access login page instead of the API. Changing the "
                "endpoint signs out the current account session and clears "
                "the Cloudflare Access service token.",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = "";
                Navigator.of(context).pop(true);
              },
              child: const Text("Use production"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (saved != true || !context.mounted) return;
      // Normalize: an empty field means the production origin.
      String normalize(String value) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? platformApiProductionOrigin : trimmed;
      }

      final stored = ref.read(appSettingServiceProvider).account.customOrigin;
      final previous = normalize(stored);
      final next = normalize(controller.text);
      // Only an actual endpoint switch updates settings and signs out.
      if (previous == next) {
        // The resolved origin is unchanged, but the user asked for
        // production: drop an explicit production URL so the tile shows
        // "Production" and the setting isn't pinned to a stale value if
        // the production origin changes in a later release. The origin is
        // the same, so the session stays valid and is not revoked.
        if (controller.text.trim().isEmpty && stored.trim().isNotEmpty) {
          ref
              .read(appSettingServiceProvider.notifier)
              .update((s) => s.copyWith(account: s.account.copyWith(customOrigin: "")));
        }
        return;
      }
      // Sessions and the Cloudflare Access service token are scoped to their
      // origin; never carry either across endpoints. Revoke the current
      // session BEFORE the settings update: the update rebuilds
      // platformSessionProvider against the new origin, so logging out
      // afterwards would send the revoke there and leave the previous-origin
      // session active server-side. The logout is a best-effort server
      // revoke plus a local clear.
      await (await ref.read(platformSessionProvider.future)).logout();
      // The service token authenticates against the old origin's Access
      // gate; left in place, the rebuilt session would attach it to requests
      // against the new origin. Clear it before the settings update triggers
      // the rebuild so the next session starts without it.
      await ref.read(securePlatformSessionStoreProvider).clearCfAccessServiceToken();
      ref
          .read(appSettingServiceProvider.notifier)
          .update(
            (s) => s.copyWith(account: s.account.copyWith(customOrigin: controller.text.trim())),
          );
    } finally {
      controller.dispose();
    }
  }
}

class CloudflareAccessServiceTokenTile extends ConsumerWidget {
  const CloudflareAccessServiceTokenTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.shield_outlined),
    title: const Text("Cloudflare Access service token"),
    subtitle: const Text(
      "CF-Access-Client-Id/-Secret sent to the account API endpoint; "
      "required for the Access-protected preview environment",
    ),
    onTap: () => unawaited(_editToken(context, ref)),
  );

  Future<void> _editToken(BuildContext context, WidgetRef ref) async {
    final store = ref.read(securePlatformSessionStoreProvider);
    final (:clientId, :clientSecret) = await store.readCfAccessServiceToken();
    final idController = TextEditingController(text: clientId);
    final secretController = TextEditingController(text: clientSecret);
    try {
      if (!context.mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cloudflare Access service token"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: idController,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: "Client ID",
                  hintText: "<id>.access",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secretController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: "Client Secret",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Create in the Zero Trust dashboard: Access controls → "
                "Service credentials → Service Tokens. Requests send the "
                "CF-Access-Client-Id/-Secret headers; renew the token "
                "before its configured duration expires.",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                idController.text = "";
                secretController.text = "";
                Navigator.of(context).pop(true);
              },
              child: const Text("Clear"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.save),
            ),
          ],
        ),
      );
      if (saved != true) return;
      await store.writeCfAccessServiceToken(
        clientId: idController.text,
        clientSecret: secretController.text,
      );
      // The token is captured at session construction; rebuild so the next
      // request carries the new value.
      ref.invalidate(platformSessionProvider);
    } finally {
      idController.dispose();
      secretController.dispose();
    }
  }
}
