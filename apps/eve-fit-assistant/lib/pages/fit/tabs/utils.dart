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

    // Mirror the fit-list swipe action: only accounts holding the platform
    // post:create permission may publish fits (fail-closed while resolving).
    final canShare = ref.watch(fitShareEligibilityProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stretch each action across the tab width: a wrapping row sends
            // later buttons to a second line with mismatched alignment, while
            // full-width buttons line up with the form fields below.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showFitExportDialog(
                    context,
                    fitId: widget.fitContext.fitId,
                    initialFit: widget.fitContext.fit,
                  ),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: Text(context.l10n.fitUtilsExportButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => FitScreenshotPage(fitId: widget.fitContext.fitId),
                    ),
                  ),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(context.l10n.fitUtilsExportImageButton),
                ),
                if (canShare)
                  OutlinedButton.icon(
                    // The share dialog uploads the persisted fit
                    // (widget.fitContext.fit), not the controller values, so
                    // sharing must wait until pending metadata edits are saved
                    // or discarded.
                    onPressed: _editable
                        ? null
                        : () => showFitShareDialog(
                            context,
                            fitId: widget.fitContext.fitId,
                            initialFit: widget.fitContext.fit,
                          ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(context.l10n.fitUtilsShareButton),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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

    // Keep metadata editing local to the tab.
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
