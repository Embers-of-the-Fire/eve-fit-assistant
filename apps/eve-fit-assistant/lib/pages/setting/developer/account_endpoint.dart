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
            ? "Production ($accountApiProductionOrigin)"
            : "Custom: ${customOrigin.trim()}",
      ),
      onTap: () => unawaited(_editEndpoint(context, ref)),
    );
  }

  Future<void> _editEndpoint(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(appSettingServiceProvider).account.customOrigin,
    );
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
                helperText: "Leave empty for production ($accountApiProductionOrigin)",
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
    if (saved != true) return;
    final origin = controller.text.trim();
    ref
        .read(appSettingServiceProvider.notifier)
        .update((s) => s.copyWith(account: s.account.copyWith(customOrigin: origin)));
    // Sessions are scoped to their origin; never carry one across endpoints.
    await ref.read(accountControllerProvider.notifier).signOutLocal();
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
    final store = ref.read(accountTokenStoreProvider);
    final controller = TextEditingController(text: await store.readCfAccessToken());
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
  }
}
