part of "../page.dart";

class _UtilsTab extends ConsumerStatefulWidget {
  const _UtilsTab({required this.fitContext});

  final FitContext fitContext;

  @override
  ConsumerState<_UtilsTab> createState() => _UtilsTabState();
}

class _UtilsTabState extends ConsumerState<_UtilsTab> with AutomaticKeepAliveClientMixin {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  final _formKey = GlobalKey<FormState>();
  bool _editable = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fitContext.fit.metadata.name);
    _descriptionController = TextEditingController(
      text: widget.fitContext.fit.metadata.description,
    );
  }

  @override
  void didUpdateWidget(covariant _UtilsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editable) return;
    _nameController.text = widget.fitContext.fit.metadata.name;
    _descriptionController.text = widget.fitContext.fit.metadata.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              readOnly: !_editable,
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? context.l10n.fitUtilsNameRequired : null,
              decoration: InputDecoration(labelText: context.l10n.fitUtilsNameLabel),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              readOnly: !_editable,
              maxLines: 8,
              decoration: InputDecoration(labelText: context.l10n.fitUtilsDescriptionLabel),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 12,
              children: _editable
                  ? [
                      OutlinedButton(onPressed: _handleCancel, child: Text(context.l10n.cancel)),
                      FilledButton(onPressed: _handleSave, child: Text(context.l10n.confirm)),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: () => setState(() => _editable = true),
                        child: Text(context.l10n.edit),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleCancel() {
    setState(() {
      _editable = false;
      _nameController.text = widget.fitContext.fit.metadata.name;
      _descriptionController.text = widget.fitContext.fit.metadata.description;
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Keep metadata editing local to the tab so it mirrors the deprecated misc
    // panel without introducing another dedicated settings service.
    await widget.fitContext.fitWrapper.update(
      (storage) => storage.copyWith(
        metadata: storage.metadata.copyWith(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _editable = false);
  }
}
