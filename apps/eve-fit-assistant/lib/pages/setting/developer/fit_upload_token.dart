part of "page.dart";

class FitUploadTokenTile extends ConsumerWidget {
  const FitUploadTokenTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(
      fitUploadTokenProvider.select((token) => token.value?.isNotEmpty ?? false),
    );
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(context.l10n.fitUploadTokenTitle),
      subtitle: Text(
        configured
            ? context.l10n.fitUploadTokenConfiguredDescription
            : context.l10n.fitUploadTokenNotConfiguredDescription,
      ),
      onTap: () => unawaited(_editToken(context, ref)),
    );
  }

  Future<void> _editToken(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: await ref.read(fitUploadTokenStoreProvider).read(),
    );
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.fitUploadTokenTitle),
        content: TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            hintText: context.l10n.fitUploadTokenHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = "";
              Navigator.of(context).pop(true);
            },
            child: Text(context.l10n.fitUploadTokenClearButton),
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
    unawaited(ref.read(fitUploadTokenProvider.notifier).set(controller.text));
  }
}
