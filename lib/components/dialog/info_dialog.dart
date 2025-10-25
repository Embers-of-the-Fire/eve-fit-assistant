part of "../dialog.dart";

class InfoButton extends StatelessWidget {
  const InfoButton({required this.title, super.key, this.content});

  final String title;
  final Widget? Function()? content;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: () => showInfoDialog(context, title: title, content: content?.call()),
    icon: const Icon(Icons.info),
  );
}

Future<void> showInfoDialog(BuildContext context, {required String title, Widget? content}) =>
    showDialog<void>(
      context: context,
      builder: (context) => InfoDialog(title: title, content: content),
    );

class InfoDialog extends ConsumerWidget {
  const InfoDialog({required this.title, super.key, this.content});

  final String title;
  final Widget? content;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    title: Text(title),
    content: content,
    actions: [ElevatedButton(onPressed: () => context.nav.pop(), child: Text(context.l10n.ok))],
  );
}
