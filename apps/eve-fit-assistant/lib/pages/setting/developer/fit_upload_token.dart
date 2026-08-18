part of "page.dart";

class FitUploadTokenTile extends ConsumerWidget {
  const FitUploadTokenTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configured = ref.watch(
      appSettingServiceProvider.select((s) => s.fitStorageUploadToken.isNotEmpty),
    );
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: const Text("Fit storage upload token"),
      subtitle: Text(
        configured
            ? "Configured — fit uploads to the platform are enabled"
            : "Not configured — required to upload fits to the platform",
      ),
      onTap: () => unawaited(_editToken(context, ref)),
    );
  }

  Future<void> _editToken(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: ref.read(appSettingServiceProvider).fitStorageUploadToken,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fit storage upload token"),
        content: TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            hintText: "Bearer token for api.efa-tech.dev fit storage",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.text = "";
              Navigator.of(context).pop(true);
            },
            child: const Text("Clear"),
          ),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Save")),
        ],
      ),
    );
    if (saved != true) return;
    final token = controller.text.trim();
    ref
        .read(appSettingServiceProvider.notifier)
        .update((setting) => setting.copyWith(fitStorageUploadToken: token));
  }
}
