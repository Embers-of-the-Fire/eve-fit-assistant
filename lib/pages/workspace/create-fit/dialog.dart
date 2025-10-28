part of "page.dart";

Future<String?> _showShipCreateDialog(BuildContext context, {required int shipId}) => showDialog(
  context: context,
  builder: (context) => _ShipCreateDialog(shipId: shipId),
);

class _ShipCreateDialog extends ConsumerStatefulWidget {
  _ShipCreateDialog({required this.shipId, super.key});

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
    final shipNameId = ref.read(
      bundleCollectionGetTypeProvider(widget.shipId).select((t) => t?.typeName.id ?? -1),
    );
    final shipName = ref.read(localizationProvider(shipNameId)) ?? "";
    _textController = TextEditingController(
      text: context.l10n.fitCreationPageDialogHint(shipName: shipName),
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
          for (final fit in relatedFits) ListTile(title: Text(fit.name)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.nav.pop(), child: Text(context.l10n.cancel)),
        TextButton(
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
