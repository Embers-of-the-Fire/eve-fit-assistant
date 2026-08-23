part of "page.dart";

/// Developer-only tiles for pointing the platform account client at the
/// preview deployment and for supplying the Cloudflare Access token that
/// deployment requires. Hardcoded English per the dev-only localization rule.
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
                "requests without a valid cf-access-token (below) get "
                "the Access login page instead of the API. Changing the "
                "endpoint signs out the current account session.",
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

      final previous = normalize(ref.read(appSettingServiceProvider).account.customOrigin);
      final next = normalize(controller.text);
      // Only an actual endpoint switch updates settings and signs out.
      if (previous == next) return;
      // Sessions are scoped to their origin; never carry one across
      // endpoints. Revoke the current session BEFORE the settings update:
      // the update rebuilds platformSessionProvider against the new origin,
      // so logging out afterwards would send the revoke there and leave the
      // previous-origin session active server-side. The logout is a
      // best-effort server revoke plus a local clear.
      await (await ref.read(platformSessionProvider.future)).logout();
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

class CloudflareAccessTokenTile extends ConsumerWidget {
  const CloudflareAccessTokenTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.shield_outlined),
    title: const Text("Cloudflare Access token"),
    subtitle: const Text(
      "cf-access-token sent to the account API endpoint; required for the "
      "Access-protected preview environment",
    ),
    onTap: () => unawaited(_editToken(context, ref)),
  );

  Future<void> _editToken(BuildContext context, WidgetRef ref) async {
    final store = ref.read(securePlatformSessionStoreProvider);
    final controller = TextEditingController(text: await store.readCfAccessToken());
    try {
      if (!context.mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Cloudflare Access token"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: "cf-access-token",
                  hintText: "cloudflared access token -app=<origin>",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Obtain with: cloudflared access token -app=\n"
                "https://efa-platform-api-preview.<subdomain>.workers.dev "
                "(re-run after the Access session expires).",
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.text = "";
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
      await store.writeCfAccessToken(controller.text);
      // The token is captured at session construction; rebuild so the next
      // request carries the new value.
      ref.invalidate(platformSessionProvider);
    } finally {
      controller.dispose();
    }
  }
}
