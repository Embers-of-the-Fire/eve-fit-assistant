part of "../dialog.dart";

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  Widget? content,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => ConfirmDialog(title: title, content: content),
  );
  return confirmed ?? false;
}

class ConfirmDialog extends ConsumerWidget {
  const ConfirmDialog({required this.title, super.key, this.content});

  final String title;
  final Widget? content;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    title: Text(title),
    content: content,
    actions: [
      TextButton(onPressed: () => context.nav.pop(false), child: Text(context.l10n.cancel)),
      ElevatedButton(onPressed: () => context.nav.pop(true), child: Text(context.l10n.confirm)),
    ],
  );
}
