part of "page.dart";

Future<String?> _showShipCreateDialog(
  BuildContext context,
  WidgetRef ref, {
  required int shipId,
}) async {
  final out = await showDialog<String?>(
    context: context,
    builder: (context) => _ShipCreateDialog(shipId: shipId),
  );
  if (out == null || out.isEmpty) return null;
  info('Creating ship $shipId with name "$out"');

  final newFitMetadata = await ref.watch(fitManagerProvider.notifier).newFit(shipId, out);

  return newFitMetadata.fitId;
}

class _ShipCreateDialog extends ConsumerStatefulWidget {
  const _ShipCreateDialog({required this.shipId});

  final int shipId;
  @override
  ConsumerState createState() => _ShipCreateDialogState();
}

class _ShipCreateDialogState extends ConsumerState<_ShipCreateDialog> {
  late final TextEditingController _textController;
  bool _initialized = false;
  final _form = GlobalKey<FormState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _textController = TextEditingController(
      text: context.l10n.fitCreationPageDialogHint(
        count: ref.read(fitsForShipProvider(widget.shipId).select((t) => t.length + 1)),
      ),
    );
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final relatedFits = ref.watch(fitsForShipProvider(widget.shipId));
    return AppDialog(
      title: context.l10n.fitCreationPageTitle,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Form(
            key: _form,
            child: TextFormField(
              controller: _initialized.thenSome(_textController),
              validator: (value) =>
                  value?.isEmpty ?? true ? context.l10n.fitCreationPageDialogErrorText : null,
            ),
          ),
          for (final fit in relatedFits)
            ListTile(
              title: Text(fit.name),
              subtitle: Text(
                yMMMMdHmsLocalized(
                  context,
                ).format(DateTime.fromMillisecondsSinceEpoch(fit.lastModified).toLocal()),
              ),
              onTap: () {
                debug("Open other saved fit ${fit.name} ${fit.fitId}");
                unawaited(context.router.popAndPush(FitRoute(fitId: fit.fitId)));
              },
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.nav.pop(), child: Text(context.l10n.cancel)),
        ElevatedButton(
          onPressed: () {
            if (_form.currentState?.validate() ?? false) {
              context.nav.pop(_textController.text);
            }
          },
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
