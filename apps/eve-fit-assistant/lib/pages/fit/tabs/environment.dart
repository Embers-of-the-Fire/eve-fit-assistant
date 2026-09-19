part of "../page.dart";

String _localizedSystemEffectName(String zh, String en, String locale) => locale == "zh" ? zh : en;

String _localizedBuffName(BuildContext context, int buffId, String locale) {
  final entry = systemBuffLibraryById[buffId];
  return entry != null
      ? _localizedSystemEffectName(entry.zh, entry.en, locale)
      : context.l10n.fitEnvironmentUnknownBuff(buffId: buffId);
}

/// Snapshot of the engine-side beacon dogma used to resolve environment
/// presets and custom-buff defaults against the active snapshot.
class _EnvironmentDogma {
  const _EnvironmentDogma({required this.engineAvailable, required this.attrsOf});

  /// Whether the fit engine was available to answer dogma queries. When
  /// false, [attrsOf] resolves nothing and the preset picker shows an
  /// unavailable hint; stored fits keep simulating (their buffs carry
  /// concrete values).
  final bool engineAvailable;

  /// Raw dogma attributes of a beacon type, null when absent from the
  /// active snapshot.
  final DogmaAttributesOf attrsOf;

  static const unavailable = _EnvironmentDogma(engineAvailable: false, attrsOf: _nullAttrs);

  static Map<int, double>? _nullAttrs(int typeId) => null;
}

/// Fetches the dogma of every beacon referenced by the catalog (presets and
/// custom-buff defaults) from the active engine data in one batch.
Future<_EnvironmentDogma> _loadEnvironmentDogma(native_server.FitEngineData? data) async {
  if (data == null) return _EnvironmentDogma.unavailable;

  final typeIds = <int>{
    for (final preset in systemEffectCatalog) ?preset.beaconTypeId,
    for (final entry in systemBuffLibrary) ?entry.defaultBeaconTypeId,
  };
  final fetched = await Future.wait(
    typeIds.map((typeId) async => MapEntry(typeId, await data.getDogmaAttributes(typeId: typeId))),
  );
  final dogma = <int, Map<int, double>>{
    for (final entry in fetched)
      if (entry.value.isNotEmpty)
        entry.key: {for (final attr in entry.value) attr.attributeId: attr.value},
  };
  return _EnvironmentDogma(engineAvailable: true, attrsOf: (typeId) => dogma[typeId]);
}

class _EnvironmentTab extends ConsumerStatefulWidget {
  const _EnvironmentTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  ConsumerState<_EnvironmentTab> createState() => _EnvironmentTabState();
}

class _EnvironmentTabState extends ConsumerState<_EnvironmentTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final fitContext = widget.fitContext;
    final interactionOptions = widget.interactionOptions;
    final buffs = fitContext.fit.body.systemBuffs;

    final presetIds = <String>[];
    for (final buff in buffs) {
      final presetId = buff.presetId;
      if (presetId != null && !presetIds.contains(presetId)) {
        presetIds.add(presetId);
      }
    }
    final customBuffs = buffs.where((buff) => buff.presetId == null).toList();

    return Column(
      children: [
        _EquipmentHeader(
          title: context.l10n.fitEnvironmentPresets,
          actions: [
            if (interactionOptions.allowMutations)
              InkWell(onTap: () => _handleAddPreset(context), child: const Icon(Icons.add)),
            if (interactionOptions.allowMutations)
              _ActionClearAll(onTap: fitContext.fitWrapper.clearSystemBuffs),
          ],
        ),
        Expanded(
          child: ListView(
            children: [
              for (final presetId in presetIds)
                _EnvironmentPresetRow(
                  fitContext: fitContext,
                  presetId: presetId,
                  interactionOptions: interactionOptions,
                ),
              if (interactionOptions.allowMutations || customBuffs.isNotEmpty)
                ListTile(
                  dense: true,
                  title: Text(
                    context.l10n.fitEnvironmentCustomBuffs,
                    style: context.theme.textTheme.titleSmall,
                  ),
                  trailing: interactionOptions.allowMutations
                      ? InkWell(
                          onTap: () => _handleAddCustomBuff(context),
                          child: const Icon(Icons.add, size: 20),
                        )
                      : null,
                ),
              for (final buff in customBuffs)
                _CustomSystemBuffRow(
                  fitContext: fitContext,
                  buff: buff,
                  interactionOptions: interactionOptions,
                ),
              if (presetIds.isEmpty && customBuffs.isEmpty)
                Padding(
                  padding: const .symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    context.l10n.fitEnvironmentEmpty,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleAddPreset(BuildContext context) async {
    final data = ref.read(nativeFitEngineServiceProvider).engineOrNull?.shareData();
    final dogma = await _loadEnvironmentDogma(data);
    if (!context.mounted) return;
    final preset = await showDialog<SystemEffectPreset>(
      context: context,
      builder: (context) => _SystemEffectPresetDialog(dogma: dogma),
    );
    if (preset == null) return;
    await _applyPreset(preset, dogma);
  }

  /// Resolves a picked preset against the active snapshot and applies it.
  /// Unresolvable presets are filtered out of the picker, so a null
  /// resolution here only races a snapshot switch and is dropped silently.
  Future<void> _applyPreset(SystemEffectPreset preset, _EnvironmentDogma dogma) async {
    final buffs = resolvePresetBuffs(preset, dogma.attrsOf);
    if (buffs == null) return;
    await widget.fitContext.fitWrapper.setSystemEffectPreset(preset.id, buffs);
  }

  Future<void> _handleAddCustomBuff(BuildContext context) async {
    final data = ref.read(nativeFitEngineServiceProvider).engineOrNull?.shareData();
    final dogma = await _loadEnvironmentDogma(data);
    if (!context.mounted) return;
    final entry = await showDialog<SystemBuffLibraryEntry>(
      context: context,
      builder: (context) => _CustomSystemBuffDialog(dogma: dogma),
    );
    if (entry == null) return;
    final value = resolveLibraryDefaultValue(entry, dogma.attrsOf);
    await widget.fitContext.fitWrapper.addCustomSystemBuff(entry.buffId, value);
  }
}

class _EnvironmentPresetRow extends ConsumerWidget {
  const _EnvironmentPresetRow({
    required this.fitContext,
    required this.presetId,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final String presetId;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).name;
    final preset = systemEffectPresetById[presetId];
    final presetBuffs = fitContext.fit.body.systemBuffs
        .where((buff) => buff.presetId == presetId)
        .toList();

    final content = Column(
      children: [
        ListTile(
          leading: const Icon(Icons.public),
          title: Text(
            preset != null
                ? _localizedSystemEffectName(preset.zh, preset.en, locale)
                : context.l10n.fitEnvironmentUnknownPreset(presetId: presetId),
          ),
          subtitle: preset != null
              ? Text(
                  "${_localizedSystemEffectName(preset.category.zh, preset.category.en, locale)} ×${presetBuffs.length}",
                )
              : null,
          onTap: interactionOptions.allowMutations ? () => _handleReplace(context, ref) : null,
        ),
        for (final buff in presetBuffs)
          ListTile(
            dense: true,
            contentPadding: const .only(left: 56, right: 24),
            title: Text(
              _localizedBuffName(context, buff.buffId, locale),
              style: context.theme.textTheme.bodySmall,
            ),
            trailing: Text("${buff.value}", style: context.theme.textTheme.bodySmall),
          ),
      ],
    );

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.removeSystemEffectPreset(presetId),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: SlidableEdgeZone(child: content),
    );
  }

  Future<void> _handleReplace(BuildContext context, WidgetRef ref) async {
    final data = ref.read(nativeFitEngineServiceProvider).engineOrNull?.shareData();
    final dogma = await _loadEnvironmentDogma(data);
    if (!context.mounted) return;
    final preset = await showDialog<SystemEffectPreset>(
      context: context,
      builder: (context) => _SystemEffectPresetDialog(dogma: dogma),
    );
    if (preset == null) return;
    // Unresolvable presets are filtered out of the picker; a null resolution
    // here only races a snapshot switch and is dropped silently.
    final buffs = resolvePresetBuffs(preset, dogma.attrsOf);
    if (buffs == null) return;
    await fitContext.fitWrapper.setSystemEffectPreset(preset.id, buffs);
  }
}

class _CustomSystemBuffRow extends ConsumerWidget {
  const _CustomSystemBuffRow({
    required this.fitContext,
    required this.buff,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitSystemBuff buff;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider).name;
    final entry = systemBuffLibraryById[buff.buffId];

    final content = ListTile(
      leading: const Icon(Icons.tune),
      title: Text(
        entry != null
            ? _localizedSystemEffectName(entry.zh, entry.en, locale)
            : context.l10n.fitEnvironmentUnknownBuff(buffId: buff.buffId),
      ),
      trailing: Text("${context.l10n.fitEnvironmentBuffValue} ${buff.value}"),
      onTap: interactionOptions.allowMutations ? () => _handleEditValue(context) : null,
    );

    if (!interactionOptions.allowMutations) return content;

    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.15,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitContext.fitWrapper.removeCustomSystemBuff(buff.buffId),
            backgroundColor: colorActionDelete,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: context.l10n.delete,
            padding: .zero,
          ),
        ],
      ),
      child: SlidableEdgeZone(child: content),
    );
  }

  Future<void> _handleEditValue(BuildContext context) async {
    final value = await showDialog<double>(
      context: context,
      builder: (context) => _EditSystemBuffValueDialog(initialValue: buff.value),
    );
    if (value == null) return;
    await fitContext.fitWrapper.updateCustomSystemBuff(buff.buffId, value);
  }
}

class _SystemEffectPresetDialog extends ConsumerStatefulWidget {
  const _SystemEffectPresetDialog({required this.dogma});

  /// Beacon dogma of the active snapshot; presets whose beacon does not
  /// resolve are hidden from the picker.
  final _EnvironmentDogma dogma;

  @override
  ConsumerState<_SystemEffectPresetDialog> createState() => _SystemEffectPresetDialogState();
}

class _SystemEffectPresetDialogState extends ConsumerState<_SystemEffectPresetDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final query = _query.trim().toLowerCase();

    String nameOf(SystemEffectPreset preset) =>
        _localizedSystemEffectName(preset.zh, preset.en, locale);
    String categoryOf(SystemEffectCategory category) =>
        _localizedSystemEffectName(category.zh, category.en, locale);

    bool matches(SystemEffectPreset preset) =>
        query.isEmpty ||
        preset.en.toLowerCase().contains(query) ||
        preset.zh.contains(query) ||
        categoryOf(preset.category).toLowerCase().contains(query);

    bool resolvable(SystemEffectPreset preset) =>
        resolvePresetBuffs(preset, widget.dogma.attrsOf) != null;

    final grouped = <SystemEffectCategory, List<SystemEffectPreset>>{};
    for (final preset in systemEffectCatalog.where(matches).where(resolvable)) {
      grouped.putIfAbsent(preset.category, () => []).add(preset);
    }

    return AppDialog(
      title: context.l10n.fitEnvironmentAddPreset,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.dogma.engineAvailable)
            Padding(
              padding: const .fromLTRB(16, 0, 16, 8),
              child: Text(
                context.l10n.fitEnvironmentEngineUnavailable,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: context.theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Padding(
            padding: const .fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.typeSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final category in SystemEffectCategory.values)
                    if (grouped.containsKey(category))
                      ExpansionTile(
                        initiallyExpanded: query.isNotEmpty || grouped.length == 1,
                        title: Text(categoryOf(category)),
                        children: [
                          for (final preset in grouped[category]!)
                            ListTile(
                              title: Text(nameOf(preset)),
                              onTap: () => Navigator.of(context).pop(preset),
                            ),
                        ],
                      ),
                  if (grouped.isEmpty)
                    Padding(
                      padding: const .symmetric(horizontal: 24, vertical: 16),
                      child: Text(
                        context.l10n.typeSearchNoResults,
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSystemBuffDialog extends ConsumerStatefulWidget {
  const _CustomSystemBuffDialog({required this.dogma});

  /// Beacon dogma of the active snapshot, used to display the resolved
  /// default strength of each entry.
  final _EnvironmentDogma dogma;

  @override
  ConsumerState<_CustomSystemBuffDialog> createState() => _CustomSystemBuffDialogState();
}

class _CustomSystemBuffDialogState extends ConsumerState<_CustomSystemBuffDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = "";

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final query = _query.trim().toLowerCase();

    String nameOf(SystemBuffLibraryEntry entry) =>
        _localizedSystemEffectName(entry.zh, entry.en, locale);

    final entries = systemBuffLibrary
        .where(
          (entry) =>
              query.isEmpty || entry.en.toLowerCase().contains(query) || entry.zh.contains(query),
        )
        .toList();

    return AppDialog(
      title: context.l10n.fitEnvironmentAddCustomBuff,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const .fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.l10n.typeSearchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in entries)
                    ListTile(
                      title: Text(nameOf(entry)),
                      trailing: Text("${resolveLibraryDefaultValue(entry, widget.dogma.attrsOf)}"),
                      onTap: () => Navigator.of(context).pop(entry),
                    ),
                  if (entries.isEmpty)
                    Padding(
                      padding: const .symmetric(horizontal: 24, vertical: 16),
                      child: Text(
                        context.l10n.typeSearchNoResults,
                        style: context.theme.textTheme.titleMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSystemBuffValueDialog extends StatefulWidget {
  const _EditSystemBuffValueDialog({required this.initialValue});

  final double initialValue;

  @override
  State<_EditSystemBuffValueDialog> createState() => _EditSystemBuffValueDialogState();
}

class _EditSystemBuffValueDialogState extends State<_EditSystemBuffValueDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: "${widget.initialValue}");
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: context.l10n.fitEnvironmentEditBuffValue,
    content: Padding(
      padding: const .fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          isDense: true,
          labelText: context.l10n.fitEnvironmentBuffValue,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: _submit,
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
      FilledButton(onPressed: () => _submit(_controller.text), child: Text(context.l10n.confirm)),
    ],
  );

  void _submit(String text) {
    final value = double.tryParse(text.trim());
    if (value == null) return;
    Navigator.of(context).pop(value);
  }
}
