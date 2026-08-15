import "dart:async";
import "dart:math";

import "package:efa_proto/dogma_attributes.pb.dart";
import "package:efa_proto/dogma_units.pb.dart";
import "package:efa_proto/dynamic.pb.dart" as pb_dynamic;
import "package:efa_proto/fit.pb.dart" show Slots;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:efa_proto/utils.pb.dart" show LocalizationID;
import "package:eve_fit_assistant/components/description_text.dart";
import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/pages/item-detail/dogma_unit_display.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart"
    show attributeDebugViewProvider, localeProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:eve_fit_assistant/utils/skill.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const List<int> _requiredSkillAttributeIds = [182, 183, 184, 1285, 1289, 1290];
const List<int> _requiredSkillLevelAttributeIds = [277, 278, 279, 1286, 1287, 1288];
const int _baseItemDetailTabCount = 3;
const int _attributeDetailTabCount = 2;
final _random = Random();

enum ItemDetailFitObjectKind { hull, module, implant, booster }

class ItemDetailFitReference {
  const ItemDetailFitReference({
    required this.fitId,
    required this.kind,
    this.index,
    this.slotType,
    this.inspectCharge = false,
  }) : assert(
         kind != ItemDetailFitObjectKind.module || slotType != null,
         "Module fit references must include a slot type.",
       );

  const ItemDetailFitReference.module({
    required String fitId,
    required native.OutSlotType slotType,
    required int index,
    bool inspectCharge = false,
  }) : this(
         fitId: fitId,
         kind: ItemDetailFitObjectKind.module,
         index: index,
         slotType: slotType,
         inspectCharge: inspectCharge,
       );

  const ItemDetailFitReference.implant({required String fitId, required int index})
    : this(fitId: fitId, kind: ItemDetailFitObjectKind.implant, index: index);

  const ItemDetailFitReference.booster({required String fitId, required int index})
    : this(fitId: fitId, kind: ItemDetailFitObjectKind.booster, index: index);

  const ItemDetailFitReference.hull({required String fitId})
    : this(fitId: fitId, kind: ItemDetailFitObjectKind.hull);

  final String fitId;
  final ItemDetailFitObjectKind kind;
  final int? index;
  final native.OutSlotType? slotType;
  final bool inspectCharge;
}

Future<void> showItemDetailPage(
  BuildContext context, {
  required int typeId,
  ItemDetailFitReference? fitReference,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) => ItemDetailPage(typeId: typeId, fitReference: fitReference),
  ),
);

Future<void> showAttributeDetailPage(
  BuildContext context, {
  required int typeId,
  required int attributeId,
  ItemDetailFitReference? fitReference,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (context) =>
        AttributeDetailPage(typeId: typeId, attributeId: attributeId, fitReference: fitReference),
  ),
);

class ItemDetailPage extends ConsumerWidget {
  const ItemDetailPage({required this.typeId, super.key, this.fitReference});

  final int typeId;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
    if (type == null) {
      final unavailable = context.l10n.fallbackTypeUnavailable(typeId: typeId);
      return Layout(
        title: unavailable,
        child: Center(child: Text(unavailable)),
      );
    }

    final itemName =
        _resolveLocalization(ref, type.typeName) ?? context.l10n.fallbackTypeName(typeId: typeId);
    final fit = fitReference == null ? null : ref.watch(fitProvider(fitReference!.fitId));
    final emulated = fitReference == null
        ? null
        : ref.watch(nativeEmulatedShipProvider(fitReference!.fitId));
    final resolvedItem = switch ((fitReference, fit?.isInitialized ?? false, emulated)) {
      (final ItemDetailFitReference reference?, true, final native.Ship ship?) =>
        _resolveNativeItem(ship, reference),
      _ => null,
    };
    final dynamicEditor = switch ((fitReference, fit?.isInitialized ?? false)) {
      (final ItemDetailFitReference reference?, true) => _resolveDynamicEditor(
        ref,
        fit!.fit,
        reference,
      ),
      _ => null,
    };

    final attributes = _collectInspectableAttributes(context.l10n, ref, type, resolvedItem);
    final description = type.hasDescription() ? _resolveLocalization(ref, type.description) : null;

    return Layout(
      title: itemName,
      child: _ItemDetailColumns(
        typeId: typeId,
        type: type,
        fitReference: fitReference,
        dynamicEditor: dynamicEditor,
        description: description,
        attributes: attributes,
        resolvedItem: resolvedItem,
      ),
    );
  }
}

class _ItemDetailColumns extends StatelessWidget {
  const _ItemDetailColumns({
    required this.typeId,
    required this.type,
    required this.fitReference,
    required this.dynamicEditor,
    required this.description,
    required this.attributes,
    required this.resolvedItem,
  });

  final int typeId;
  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;
  final _DynamicEditorContext? dynamicEditor;
  final String? description;
  final List<_InspectableAttribute> attributes;
  final native.Item? resolvedItem;

  @override
  Widget build(BuildContext context) {
    final tabCount = _itemDetailTabCount(dynamicEditor != null);
    final columns = columnCount(context);
    final paneCount = columns >= tabCount ? tabCount : columns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (var index = 0; index < paneCount; index++) ...[
            if (index > 0) const VerticalDivider(indent: 8, endIndent: 8),
            Expanded(
              child: _ItemDetailTabPane(
                initialIndex: index,
                typeId: typeId,
                type: type,
                fitReference: fitReference,
                dynamicEditor: dynamicEditor,
                description: description,
                attributes: attributes,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemDetailTabPane extends StatefulWidget {
  const _ItemDetailTabPane({
    required this.initialIndex,
    required this.typeId,
    required this.type,
    required this.fitReference,
    required this.dynamicEditor,
    required this.description,
    required this.attributes,
  });

  final int initialIndex;
  final int typeId;
  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;
  final _DynamicEditorContext? dynamicEditor;
  final String? description;
  final List<_InspectableAttribute> attributes;

  @override
  State<_ItemDetailTabPane> createState() => _ItemDetailTabPaneState();
}

class _ItemDetailTabPaneState extends State<_ItemDetailTabPane>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int get _tabCount => _itemDetailTabCount(widget.dynamicEditor != null);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.initialIndex,
      length: _tabCount,
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(covariant _ItemDetailTabPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousCount = _itemDetailTabCount(oldWidget.dynamicEditor != null);
    if (previousCount == _tabCount) return;

    final nextIndex = _tabController.index.clamp(0, _tabCount - 1);
    _tabController.dispose();
    _tabController = TabController(initialIndex: nextIndex, length: _tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabController,
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(text: context.l10n.itemDetailTabInfo),
          if (widget.dynamicEditor != null) Tab(text: context.l10n.itemDetailTabDynamic),
          Tab(text: context.l10n.itemDetailTabAttributes),
          Tab(text: context.l10n.itemDetailTabSkills),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _ItemTabContent(
              typeId: widget.typeId,
              type: widget.type,
              fitReference: widget.fitReference,
              description: widget.description,
            ),
            if (widget.dynamicEditor != null)
              _DynamicAttributeTabContent(dynamicEditor: widget.dynamicEditor!),
            _AttributeTabContent(
              typeId: widget.typeId,
              fitReference: widget.fitReference,
              attributes: widget.attributes,
            ),
            _SkillTabContent(type: widget.type, fitReference: widget.fitReference),
          ],
        ),
      ),
    ],
  );
}

class _ItemTabContent extends ConsumerWidget {
  const _ItemTabContent({
    required this.typeId,
    required this.type,
    required this.fitReference,
    required this.description,
  });

  final int typeId;
  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;
  final String? description;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _HeaderCard(type: type, fitReference: fitReference),
      const SizedBox(height: 12),
      _ClassificationCard(type: type),
      if (description?.trim().isNotEmpty ?? false) ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.itemDetailDescription,
          child: DescriptionText(text: description!, style: context.theme.textTheme.bodyMedium),
        ),
      ],
      if (type.traitSections.isNotEmpty) ...[
        const SizedBox(height: 12),
        _TraitCard(type: type, fitReference: fitReference),
      ],
      if (_hasSlotSummary(ref, typeId)) ...[
        const SizedBox(height: 12),
        _SlotSummaryCard(typeId: typeId),
      ],
    ],
  );
}

class _AttributeTabContent extends StatelessWidget {
  const _AttributeTabContent({
    required this.typeId,
    required this.fitReference,
    required this.attributes,
  });

  final int typeId;
  final ItemDetailFitReference? fitReference;
  final List<_InspectableAttribute> attributes;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      if (attributes.isNotEmpty)
        _AttributesList(typeId: typeId, fitReference: fitReference, attributes: attributes),
    ],
  );
}

class _SkillTabContent extends StatelessWidget {
  const _SkillTabContent({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (type.requiredSkills.isNotEmpty) _SkillTree(type: type, fitReference: fitReference),
    ],
  );
}

class AttributeDetailPage extends ConsumerWidget {
  const AttributeDetailPage({
    required this.typeId,
    required this.attributeId,
    super.key,
    this.fitReference,
  });

  final int typeId;
  final int attributeId;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns = columnCount(context);
    final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
    final attribute = ref.watch(
      repoCollectionProvider.select((c) => c?.getDogmaAttribute(attributeId)),
    );
    final unit = attribute?.hasUnitId() ?? false
        ? ref.watch(repoCollectionProvider.select((c) => c?.getDogmaUnit(attribute!.unitId)))
        : null;
    final fit = fitReference == null ? null : ref.watch(fitProvider(fitReference!.fitId));
    final emulated = fitReference == null
        ? null
        : ref.watch(nativeEmulatedShipProvider(fitReference!.fitId));
    final resolvedItem = switch ((fitReference, fit?.isInitialized ?? false, emulated)) {
      (final ItemDetailFitReference reference?, true, final native.Ship ship?) =>
        _resolveNativeItem(ship, reference),
      _ => null,
    };
    final staticValue = _staticAttributeValue(type, attributeId);
    final current = resolvedItem?.attributes[attributeId];
    final title =
        _attributeDisplayName(ref, attribute) ??
        context.l10n.fallbackAttributeName(attributeId: attributeId);

    return Layout(
      title: title,
      child: columns <= 1
          ? _AttributeDetailTabPane(
              typeId: typeId,
              attributeId: attributeId,
              attribute: attribute,
              unit: unit,
              staticValue: staticValue,
              current: current,
              fit: fit?.fit,
              emulated: emulated,
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  Expanded(
                    child: _AttributeOverviewContent(
                      typeId: typeId,
                      attributeId: attributeId,
                      attribute: attribute,
                      unit: unit,
                      staticValue: staticValue,
                      current: current,
                    ),
                  ),
                  const VerticalDivider(indent: 8, endIndent: 8),
                  Expanded(
                    child: _AttributeEffectChainContent(
                      attribute: attribute,
                      modifiers: current?.trackedModifiers ?? const <native.ModifierTracker>[],
                      fit: fit?.fit,
                      emulated: emulated,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DynamicAttributeTabContent extends ConsumerWidget {
  const _DynamicAttributeTabContent({required this.dynamicEditor});

  final _DynamicEditorContext dynamicEditor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitState = ref.watch(fitProvider(dynamicEditor.fitId));
    if (!fitState.isInitialized) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: context.l10n.itemDetailTabDynamic,
            child: Text(context.l10n.itemDetailDynamicUnavailable),
          ),
        ],
      );
    }

    final dynamicItem = fitState.fit.dynamicRegistry.dynamicItems[dynamicEditor.dynamicItemId];
    if (dynamicItem == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: context.l10n.itemDetailTabDynamic,
            child: Text(context.l10n.itemDetailDynamicMissing),
          ),
        ],
      );
    }

    final fitNotifier = ref.read(fitProvider(dynamicEditor.fitId).notifier);
    final rows = dynamicEditor.dynamicMutator.attributes.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: context.l10n.itemDetailTabDynamic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ValueChip(
                    label: context.l10n.itemDetailDynamicBaseItem,
                    value:
                        _resolveLocalization(ref, dynamicEditor.originType.typeName) ??
                        context.l10n.fallbackTypeName(typeId: dynamicEditor.originType.typeId),
                  ),
                  _ValueChip(
                    label: context.l10n.itemDetailDynamicMutator,
                    value:
                        _resolveLocalization(ref, dynamicEditor.modifierType.typeName) ??
                        context.l10n.fallbackTypeName(typeId: dynamicEditor.modifierType.typeId),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => fitNotifier.update((fit) {
                      final item = fit.dynamicRegistry.dynamicItems[dynamicEditor.dynamicItemId];
                      if (item == null) return fit;
                      return fit.copyWith(
                        dynamicRegistry: fit.dynamicRegistry.copyWith(
                          dynamicItems: fit.dynamicRegistry.dynamicItems.add(
                            dynamicEditor.dynamicItemId,
                            item.copyWith(
                              dynamicAttributes: IMap.fromEntries(
                                item.dynamicAttributes.keys.map(
                                  (attributeId) => MapEntry<int, double>(attributeId, 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    icon: const Icon(Icons.restore),
                    label: Text(context.l10n.itemDetailDynamicReset),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => fitNotifier.update((fit) {
                      final item = fit.dynamicRegistry.dynamicItems[dynamicEditor.dynamicItemId];
                      if (item == null) return fit;
                      return fit.copyWith(
                        dynamicRegistry: fit.dynamicRegistry.copyWith(
                          dynamicItems: fit.dynamicRegistry.dynamicItems.add(
                            dynamicEditor.dynamicItemId,
                            item.copyWith(
                              dynamicAttributes: IMap.fromEntries(
                                dynamicEditor.dynamicMutator.attributes.entries.map((entry) {
                                  final range = entry.value;
                                  final factor =
                                      range.min + ((range.max - range.min) * _random.nextDouble());
                                  return MapEntry(entry.key, factor);
                                }),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(context.l10n.itemDetailDynamicReroll),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final entry in rows)
                () {
                  final attribute = ref.watch(
                    repoCollectionProvider.select((c) => c?.getDogmaAttribute(entry.key)),
                  );
                  return _DynamicAttributeEditorRow(
                    dynamicItemId: dynamicEditor.dynamicItemId,
                    attributeId: entry.key,
                    attribute: attribute,
                    displayName:
                        _attributeDisplayName(ref, attribute) ??
                        context.l10n.fallbackAttributeName(attributeId: entry.key),
                    baseValue: _staticAttributeValue(dynamicEditor.originType, entry.key),
                    factor: dynamicItem.dynamicAttributes[entry.key] ?? 1.0,
                    minFactor: entry.value.min,
                    maxFactor: entry.value.max,
                    fitId: dynamicEditor.fitId,
                  );
                }(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DynamicAttributeEditorRow extends ConsumerStatefulWidget {
  const _DynamicAttributeEditorRow({
    required this.dynamicItemId,
    required this.attributeId,
    required this.attribute,
    required this.displayName,
    required this.baseValue,
    required this.factor,
    required this.minFactor,
    required this.maxFactor,
    required this.fitId,
  });

  final int dynamicItemId;
  final int attributeId;
  final DogmaAttribute? attribute;
  final String displayName;
  final double? baseValue;
  final double factor;
  final double minFactor;
  final double maxFactor;
  final String fitId;

  @override
  ConsumerState<_DynamicAttributeEditorRow> createState() => _DynamicAttributeEditorRowState();
}

class _DynamicAttributeEditorRowState extends ConsumerState<_DynamicAttributeEditorRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_handleFocusChange);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant _DynamicAttributeEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        (oldWidget.factor != widget.factor || oldWidget.baseValue != widget.baseValue)) {
      _syncController();
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    unawaited(_commitValue());
  }

  void _syncController([double? factor]) {
    final baseValue = widget.baseValue;
    if (baseValue == null) {
      _controller.text = "";
      return;
    }
    _controller.text = _formatDynamicValue(baseValue * (factor ?? widget.factor));
  }

  Future<void> _commitValue() async {
    final baseValue = widget.baseValue;
    if (baseValue == null || baseValue == 0) {
      _syncController();
      return;
    }

    final parsedValue = double.tryParse(_controller.text.trim());
    if (parsedValue == null) {
      _syncController();
      return;
    }

    final minValue = baseValue * widget.minFactor;
    final maxValue = baseValue * widget.maxFactor;
    final clampedValue = parsedValue.clamp(
      minValue < maxValue ? minValue : maxValue,
      minValue < maxValue ? maxValue : minValue,
    );
    final nextFactor = clampedValue / baseValue;
    _syncController(nextFactor);

    final fitNotifier = ref.read(fitProvider(widget.fitId).notifier);
    await fitNotifier.update((fit) {
      final dynamicItem = fit.dynamicRegistry.dynamicItems[widget.dynamicItemId];
      if (dynamicItem == null) return fit;
      return fit.copyWith(
        dynamicRegistry: fit.dynamicRegistry.copyWith(
          dynamicItems: fit.dynamicRegistry.dynamicItems.add(
            widget.dynamicItemId,
            dynamicItem.copyWith(
              dynamicAttributes: dynamicItem.dynamicAttributes.add(widget.attributeId, nextFactor),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseValue = widget.baseValue;
    if (baseValue == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _SectionCard(
          title: widget.displayName,
          child: Text(
            context.l10n.itemDetailDynamicBaseAttributeUnavailable(attributeId: widget.attributeId),
          ),
        ),
      );
    }

    final currentValue = baseValue * widget.factor;
    final minValue = baseValue * widget.minFactor;
    final maxValue = baseValue * widget.maxFactor;
    final lowTone = _attributeDeltaTone(
      attribute: widget.attribute,
      baseValue: baseValue,
      currentValue: minValue,
    );
    final leftValue = lowTone == _ValueTone.negative ? minValue : maxValue;
    final rightValue = leftValue == minValue ? maxValue : minValue;
    final currentTone = _attributeDeltaTone(
      attribute: widget.attribute,
      baseValue: baseValue,
      currentValue: currentValue,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(widget.displayName, style: context.theme.textTheme.titleSmall),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onSubmitted: (_) => _commitValue(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDynamicValue(leftValue),
                  style: context.theme.textTheme.labelMedium?.copyWith(color: Colors.red.shade700),
                ),
              ),
              Expanded(
                child: Text(
                  _formatDynamicValue(currentValue),
                  textAlign: TextAlign.center,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    color: _toneColor(context, currentTone),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  _formatDynamicValue(rightValue),
                  textAlign: TextAlign.end,
                  style: context.theme.textTheme.labelMedium?.copyWith(
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DynamicAttributeRatioBar(
            factor: widget.factor,
            minFactor: widget.minFactor,
            maxFactor: widget.maxFactor,
            tone: currentTone,
          ),
        ],
      ),
    );
  }
}

class _DynamicAttributeRatioBar extends StatelessWidget {
  const _DynamicAttributeRatioBar({
    required this.factor,
    required this.minFactor,
    required this.maxFactor,
    required this.tone,
  });

  final double factor;
  final double minFactor;
  final double maxFactor;
  final _ValueTone? tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _ValueTone.positive => Colors.green.shade700,
      _ValueTone.negative => Colors.red.shade700,
      null => context.theme.colorScheme.outline,
    };
    final normalized = factor == 1
        ? 0.5
        : factor > 1
        ? 0.5 + ((factor - 1) / ((maxFactor - 1).abs() * 2)).clamp(0.0, 0.5)
        : 0.5 - ((1 - factor) / ((1 - minFactor).abs() * 2)).clamp(0.0, 0.5);

    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final center = width / 2;
          final position = normalized * width;
          final left = position < center ? position : center;
          final right = position > center ? position : center;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: context.theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(width: 1, color: context.theme.colorScheme.onSurface),
                  ),
                ),
                Positioned(
                  left: left,
                  width: right - left,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttributeDetailTabPane extends StatefulWidget {
  const _AttributeDetailTabPane({
    required this.typeId,
    required this.attributeId,
    required this.attribute,
    required this.unit,
    required this.staticValue,
    required this.current,
    required this.fit,
    required this.emulated,
  });

  final int typeId;
  final int attributeId;
  final DogmaAttribute? attribute;
  final DogmaUnit? unit;
  final double? staticValue;
  final native.Attribute? current;
  final FitStorage? fit;
  final native.Ship? emulated;

  @override
  State<_AttributeDetailTabPane> createState() => _AttributeDetailTabPaneState();
}

class _AttributeDetailTabPaneState extends State<_AttributeDetailTabPane>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _attributeDetailTabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TabBar(
        controller: _tabController,
        labelPadding: EdgeInsets.zero,
        tabs: [
          Tab(text: context.l10n.itemDetailAttributeOverview),
          Tab(text: context.l10n.itemDetailEffectChain),
        ],
      ),
      Expanded(
        child: TabBarView(
          controller: _tabController,
          children: [
            _AttributeOverviewContent(
              typeId: widget.typeId,
              attributeId: widget.attributeId,
              attribute: widget.attribute,
              unit: widget.unit,
              staticValue: widget.staticValue,
              current: widget.current,
            ),
            _AttributeEffectChainContent(
              attribute: widget.attribute,
              modifiers: widget.current?.trackedModifiers ?? const <native.ModifierTracker>[],
              fit: widget.fit,
              emulated: widget.emulated,
            ),
          ],
        ),
      ),
    ],
  );
}

class _AttributeOverviewContent extends ConsumerWidget {
  const _AttributeOverviewContent({
    required this.typeId,
    required this.attributeId,
    required this.attribute,
    required this.unit,
    required this.staticValue,
    required this.current,
  });

  final int typeId;
  final int attributeId;
  final DogmaAttribute? attribute;
  final DogmaUnit? unit;
  final double? staticValue;
  final native.Attribute? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _SectionCard(
        title: context.l10n.itemDetailAttributeOverview,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.itemDetailAttributeType, style: context.theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            TypeNameText(typeId: typeId),
            if (ref.watch(attributeDebugViewProvider)) ...[
              const SizedBox(height: 12),
              Text("Identifier", style: context.theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(
                _attributeDebugIdentifier(attributeId, attribute),
                style: const TextStyle(fontFamily: "monospace", fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      if (attribute != null && attribute!.description.isNotEmpty) ...[
        const SizedBox(height: 12),
        _SectionCard(
          title: context.l10n.itemDetailDescription,
          child: DescriptionText(
            text: attribute!.description,
            style: context.theme.textTheme.bodyMedium,
          ),
        ),
      ],
      const SizedBox(height: 12),
      _SectionCard(
        title: context.l10n.itemDetailAttributes,
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ValueChip(
              label: context.l10n.itemDetailAttributeBaseValue,
              value: staticValue == null
                  ? context.l10n.itemDetailUnavailable
                  : _formatItemDetailDogmaValue(context, ref, unit, staticValue!),
            ),
            if (current?.value != null)
              _ValueChip(
                label: context.l10n.itemDetailAttributeCurrentValue,
                value: _formatItemDetailDogmaValue(context, ref, unit, current!.value!),
                tone: staticValue == null
                    ? null
                    : _attributeDeltaTone(
                        attribute: attribute,
                        baseValue: staticValue!,
                        currentValue: current!.value!,
                      ),
              ),
            if (staticValue != null && current?.value != null && canFormatDogmaUnitDelta(unit))
              _ValueChip(
                label: context.l10n.itemDetailAttributeDelta,
                value: formatDogmaUnitDelta(
                  context,
                  ref,
                  unit,
                  baseValue: staticValue!,
                  currentValue: current!.value!,
                ),
                tone: _attributeDeltaTone(
                  attribute: attribute,
                  baseValue: staticValue!,
                  currentValue: current!.value!,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _AttributeEffectChainContent extends StatelessWidget {
  const _AttributeEffectChainContent({
    required this.modifiers,
    required this.attribute,
    required this.fit,
    required this.emulated,
  });

  final List<native.ModifierTracker> modifiers;
  final DogmaAttribute? attribute;
  final FitStorage? fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      if (modifiers.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SectionCard(
            title: context.l10n.itemDetailEffectChain,
            child: Text(context.l10n.itemDetailNoEffectChain),
          ),
        )
      else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            context.l10n.itemDetailEffectChain,
            style: context.theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < modifiers.length; index++) ...[
          _ModifierTile(
            modifier: modifiers[index],
            attribute: attribute,
            fit: fit,
            emulated: emulated,
          ),
          if (index < modifiers.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
        ],
      ],
    ],
  );
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaGroup = ref.watch(
      repoCollectionProvider.select((c) => c?.getMetaGroup(type.metaGroupId)),
    );
    final group = ref.watch(repoCollectionProvider.select((c) => c?.getGroup(type.groupId)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EveIcon(icon: type.icon, overlayIcon: metaGroup?.icon, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(localizationKey: type.typeName, formatter: (value) => value),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (metaGroup != null)
                        _TagChip(label: _resolveLocalization(ref, metaGroup.metaGroupName) ?? ""),
                      if (group != null)
                        _TagChip(label: _resolveLocalization(ref, group.groupName) ?? ""),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassificationCard extends ConsumerWidget {
  const _ClassificationCard({required this.type});

  final pb_types.Type type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(repoCollectionProvider.select((c) => c?.getGroup(type.groupId)));
    final category = group == null
        ? null
        : ref.watch(repoCollectionProvider.select((c) => c?.getCategory(group.categoryId)));
    final marketGroup = type.hasMarketGroupId()
        ? ref.watch(repoCollectionProvider.select((c) => c?.getMarketGroup(type.marketGroupId)))
        : null;

    return _SectionCard(
      title: context.l10n.itemDetailClassification,
      child: Column(
        children: [
          _DataRow(label: context.l10n.itemDetailTypeId, value: "${type.typeId}"),
          if (category != null)
            _DataRow(
              label: context.l10n.itemDetailCategory,
              value: _resolveLocalization(ref, category.categoryName) ?? "${category.categoryId}",
            ),
          if (group != null)
            _DataRow(
              label: context.l10n.itemDetailGroup,
              value: _resolveLocalization(ref, group.groupName) ?? "${group.groupId}",
            ),
          if (marketGroup != null)
            _DataRow(
              label: context.l10n.itemDetailMarketGroup,
              value:
                  _resolveLocalization(ref, marketGroup.marketGroupName) ??
                  "${marketGroup.marketGroupId}",
            ),
        ],
      ),
    );
  }
}

class _TraitCard extends ConsumerWidget {
  const _TraitCard({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SectionCard(
    title: context.l10n.itemDetailTraits,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in type.traitSections) ...[
          DescriptionText(
            text: _traitSectionLabel(ref, context, section),
            style: context.theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final entry in section.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("- "),
                  Expanded(
                    child: DescriptionText(
                      text: _traitEntryMarkup(ref, context, entry),
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class _SkillTree extends StatelessWidget {
  const _SkillTree({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final requirement in type.requiredSkills)
        _SkillTreeNode(requirement: requirement, fitReference: fitReference),
    ],
  );
}

class _SkillTreeNode extends ConsumerStatefulWidget {
  const _SkillTreeNode({required this.requirement, required this.fitReference, this.depth = 0});

  final pb_types.Type_SkillRequirement requirement;
  final ItemDetailFitReference? fitReference;
  final int depth;

  @override
  ConsumerState<_SkillTreeNode> createState() => _SkillTreeNodeState();
}

class _SkillTreeNodeState extends ConsumerState<_SkillTreeNode> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final skillType = ref.watch(
      repoCollectionProvider.select((c) => c?.getType(widget.requirement.skillTypeId)),
    );
    final childRequirements =
        skillType?.requiredSkills.toList() ?? const <pb_types.Type_SkillRequirement>[];
    final hasChildren = childRequirements.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () => showItemDetailPage(context, typeId: widget.requirement.skillTypeId),
            child: Padding(
              padding: EdgeInsets.only(left: widget.depth * 24.0, top: 5, bottom: 5, right: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: hasChildren
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
                            onPressed: () => setState(() => _expanded = !_expanded),
                            icon: Icon(
                              _expanded ? Icons.expand_more : Icons.chevron_right,
                              size: 18,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: skillType == null
                        ? Text(
                            context.l10n.fallbackTypeName(typeId: widget.requirement.skillTypeId),
                          )
                        : TypeNameText(typeId: widget.requirement.skillTypeId),
                  ),
                  const SizedBox(width: 12),
                  _LevelPips(
                    level: widget.requirement.level,
                    alphaMaxLevel: skillType?.alphaCloneMaxLevel,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (final child in childRequirements)
            _SkillTreeNode(
              requirement: child,
              fitReference: widget.fitReference,
              depth: widget.depth + 1,
            ),
      ],
    );
  }
}

class _SlotSummaryCard extends ConsumerWidget {
  const _SlotSummaryCard({required this.typeId});

  final int typeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ship = ref.watch(repoCollectionProvider.select((c) => c?.getShip(typeId)));
    final subsystem = ref.watch(repoCollectionProvider.select((c) => c?.getSubsystem(typeId)));
    final slots = ref.watch(repoCollectionProvider.select((c) => c?.slots));

    final rows = <Widget>[];
    if (ship != null) {
      rows.addAll([
        _DataRow(label: context.l10n.highSlot, value: "${ship.highSlots}"),
        _DataRow(label: context.l10n.midSlot, value: "${ship.mediumSlots}"),
        _DataRow(label: context.l10n.lowSlot, value: "${ship.lowSlots}"),
        _DataRow(label: context.l10n.rigSlot, value: "${ship.rigSlots}"),
        _DataRow(label: context.l10n.subsystemSlot, value: "${ship.subsystemSlots}"),
        _DataRow(label: context.l10n.serviceSlot, value: "${ship.serviceSlots}"),
      ]);
    }
    if (subsystem != null) {
      rows.addAll([
        _DataRow(label: context.l10n.highSlot, value: "${subsystem.highSlots}"),
        _DataRow(label: context.l10n.midSlot, value: "${subsystem.mediumSlots}"),
        _DataRow(label: context.l10n.lowSlot, value: "${subsystem.lowSlots}"),
      ]);
    }
    if (slots != null) {
      final slotClass = _renderedSlotClassLabel(context, slots, typeId);
      if (slotClass != null) {
        rows.add(_DataRow(label: context.l10n.itemDetailSlotClass, value: slotClass));
      }
    }

    return _SectionCard(
      title: context.l10n.itemDetailFitting,
      child: Column(children: rows),
    );
  }
}

class _AttributesList extends ConsumerWidget {
  const _AttributesList({
    required this.typeId,
    required this.fitReference,
    required this.attributes,
  });

  final int typeId;
  final ItemDetailFitReference? fitReference;
  final List<_InspectableAttribute> attributes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final attribute in attributes)
        SizedBox(
          width: double.infinity,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            minVerticalPadding: 8,
            minTileHeight: 0,
            leading: attribute.attribute == null
                ? const Icon(Icons.square_outlined, color: Colors.transparent, size: 24)
                : EveIcon(
                    icon: attribute.attribute!.icon,
                    fallbackIcon: const Icon(
                      Icons.square_outlined,
                      color: Colors.transparent,
                      size: 24,
                    ),
                  ),
            title: Text(attribute.displayName),
            subtitle: attribute.debugSubtitle == null
                ? null
                : Text(
                    attribute.debugSubtitle!,
                    style: const TextStyle(fontFamily: "monospace", fontSize: 11),
                  ),
            trailing: Text(
              _formatItemDetailDogmaValue(
                context,
                ref,
                attribute.unit,
                attribute.currentValue ?? attribute.staticValue,
              ),
              textAlign: TextAlign.end,
              style: context.theme.textTheme.bodyLarge?.copyWith(
                color: _toneColor(
                  context,
                  attribute.currentValue == null
                      ? null
                      : _attributeDeltaTone(
                          attribute: attribute.attribute,
                          baseValue: attribute.staticValue,
                          currentValue: attribute.currentValue!,
                        ),
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
            onLongPress: () => showAttributeDetailPage(
              context,
              typeId: typeId,
              attributeId: attribute.attributeId,
              fitReference: fitReference,
            ),
          ),
        ),
    ],
  );
}

class _ModifierTile extends ConsumerStatefulWidget {
  const _ModifierTile({
    required this.modifier,
    required this.attribute,
    required this.fit,
    required this.emulated,
  });

  final native.ModifierTracker modifier;
  final DogmaAttribute? attribute;
  final FitStorage? fit;
  final native.Ship? emulated;

  @override
  ConsumerState<_ModifierTile> createState() => _ModifierTileState();
}

class _ModifierTileState extends ConsumerState<_ModifierTile> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final modifier = widget.modifier;
    final sourceLabel = _modifierSourceLabel(
      context,
      ref,
      widget.fit,
      widget.emulated,
      modifier.source,
    );
    final appliedValue = modifier.penalizedValue;
    final headlineDisplay = _modifierHeadlineValueDisplay(
      context,
      modifier.source,
      modifier.originalValue,
      appliedValue,
    );
    final sourceDisplay = _modifierSourceValueDisplay(
      context,
      modifier.source,
      modifier.originalValue,
    );
    final transformedDisplay = _modifierAppliedValueDisplay(
      context,
      modifier.source,
      modifier.normalizedValue,
    );
    final appliedDisplay = _modifierAppliedValueDisplay(context, modifier.source, appliedValue);
    final appliedTone = _modifierValueTone(widget.attribute, modifier.source, appliedValue);
    final detail = modifier.source.when(
      effect: (effect) {
        final attribute = ref.watch(
          repoCollectionProvider.select((c) => c?.getDogmaAttribute(effect.sourceAttributeId)),
        );
        final attributeName =
            _attributeDisplayName(ref, attribute) ??
            context.l10n.fallbackAttributeName(attributeId: effect.sourceAttributeId);
        return "${_effectCategoryLabel(context, effect.sourceCategory)} - ${_effectOperatorLabel(context, effect.operator_)} - $attributeName";
      },
      buff: (buffId) => context.l10n.itemDetailBuffSource(buffId: buffId),
    );
    final hasPenalty =
        modifier.source is native.ModifierSource_Effect &&
        (modifier.source as native.ModifierSource_Effect).field0.penalty;
    final penaltyChangedValue = modifier.penalizedValue != modifier.normalizedValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _expanded = !_expanded),
                      icon: Icon(_expanded ? Icons.expand_more : Icons.chevron_right, size: 18),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(sourceLabel, style: context.theme.textTheme.titleSmall),
                            if (hasPenalty)
                              _InlineStatusChip(
                                label: context.l10n.itemDetailPenalty,
                                tone: _ValueTone.negative,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: _expanded ? null : 1,
                          overflow: _expanded ? null : TextOverflow.ellipsis,
                          style: context.theme.textTheme.bodySmall?.copyWith(
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        headlineDisplay.primary,
                        style: context.theme.textTheme.bodyLarge?.copyWith(
                          color: _toneColor(context, appliedTone),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        headlineDisplay.secondary ?? context.l10n.itemDetailApplied,
                        style: context.theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EffectSummaryChip(
                      label: context.l10n.itemDetailModifierValueSource,
                      value: sourceDisplay.primary,
                      caption: sourceDisplay.secondary,
                    ),
                    _EffectSummaryChip(
                      label: context.l10n.itemDetailModifierValueTransformed,
                      value: transformedDisplay.primary,
                      caption: transformedDisplay.secondary,
                    ),
                    _EffectSummaryChip(
                      label: hasPenalty
                          ? context.l10n.itemDetailModifierValueAppliedAfterPenalty
                          : context.l10n.itemDetailApplied,
                      value: appliedDisplay.primary,
                      caption: appliedDisplay.secondary,
                      tone: appliedTone,
                    ),
                  ],
                ),
                if (hasPenalty && penaltyChangedValue) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.itemDetailModifierStackingPenaltyHint,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (appliedDisplay.explanation != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    appliedDisplay.explanation!,
                    style: context.theme.textTheme.bodySmall?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineStatusChip extends StatelessWidget {
  const _InlineStatusChip({required this.label, required this.tone});

  final String label;
  final _ValueTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _toneBackground(context, tone),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EffectSummaryChip extends StatelessWidget {
  const _EffectSummaryChip({required this.label, required this.value, this.caption, this.tone});

  final String label;
  final String value;
  final String? caption;
  final _ValueTone? tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _toneBackground(context, tone),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tone == null
              ? context.theme.colorScheme.outlineVariant
              : color.withValues(alpha: 0.35),
        ),
      ),
      child: _EffectValueText(label: label, value: value, caption: caption, tone: tone),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 140, child: Text(label, style: context.theme.textTheme.labelLarge)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final _ValueTone? tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    final background = _toneBackground(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tone == null
              ? context.theme.colorScheme.outlineVariant
              : color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: context.theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: tone == null ? FontWeight.w500 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EffectValueText extends StatelessWidget {
  const _EffectValueText({required this.label, required this.value, this.caption, this.tone});

  final String label;
  final String value;
  final String? caption;
  final _ValueTone? tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(context, tone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(
          value,
          style: context.theme.textTheme.bodyMedium?.copyWith(
            color: tone == null ? null : color,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            style: context.theme.textTheme.labelMedium?.copyWith(
              color: tone == null ? context.theme.colorScheme.onSurfaceVariant : color,
            ),
          ),
        ],
      ],
    );
  }
}

class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level, this.alphaMaxLevel});

  final int level;
  final int? alphaMaxLevel;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (index) {
      final skillLevel = index + 1;
      final active = skillLevel <= level;
      final unavailableToAlpha = alphaMaxLevel != null && skillLevel > alphaMaxLevel!;
      final color = unavailableToAlpha ? colorSkillAlphaLimited : context.theme.colorScheme.primary;
      final borderColor = active || unavailableToAlpha ? color : context.theme.colorScheme.outline;
      return Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }),
  );
}

class _InspectableAttribute {
  const _InspectableAttribute({
    required this.attributeId,
    required this.attribute,
    required this.displayName,
    required this.staticValue,
    required this.unit,
    this.currentValue,
    this.debugSubtitle,
  });

  final int attributeId;
  final DogmaAttribute? attribute;
  final String displayName;
  final double staticValue;
  final double? currentValue;
  final DogmaUnit? unit;
  final String? debugSubtitle;
}

class _DynamicEditorContext {
  const _DynamicEditorContext({
    required this.fitId,
    required this.dynamicItemId,
    required this.originType,
    required this.modifierType,
    required this.dynamicMutator,
  });

  final String fitId;
  final int dynamicItemId;
  final pb_types.Type originType;
  final pb_types.Type modifierType;
  final pb_dynamic.DynamicMutator dynamicMutator;
}

class _ModifierValueDisplay {
  const _ModifierValueDisplay({required this.primary, this.secondary, this.explanation});

  final String primary;
  final String? secondary;
  final String? explanation;
}

enum _ValueTone { positive, negative }

int _itemDetailTabCount(bool hasDynamicEditor) =>
    _baseItemDetailTabCount + (hasDynamicEditor ? 1 : 0);

_DynamicEditorContext? _resolveDynamicEditor(
  WidgetRef ref,
  FitStorage fit,
  ItemDetailFitReference reference,
) {
  if (reference.kind != ItemDetailFitObjectKind.module || reference.inspectCharge) {
    return null;
  }

  final index = reference.index;
  final slotType = reference.slotType;
  if (index == null || slotType == null) {
    return null;
  }

  final slot = _resolveStoredModule(fit, slotType, index);
  final dynamicId = slot?.itemId.dynamicIdOrNull;
  if (dynamicId == null) {
    return null;
  }

  final dynamicItem = fit.dynamicRegistry.dynamicItems[dynamicId];
  if (dynamicItem == null) {
    return null;
  }

  final dynamicMutator = ref
      .watch(repoCollectionProvider)
      ?.getDynamicMutator(dynamicItem.modifierTypeId);
  final originType = ref.watch(
    repoCollectionProvider.select((c) => c?.getType(dynamicItem.originTypeId)),
  );
  final modifierType = ref.watch(
    repoCollectionProvider.select((c) => c?.getType(dynamicItem.modifierTypeId)),
  );
  if (dynamicMutator == null || originType == null || modifierType == null) {
    return null;
  }

  return _DynamicEditorContext(
    fitId: fit.metadata.fitId,
    dynamicItemId: dynamicId,
    originType: originType,
    modifierType: modifierType,
    dynamicMutator: dynamicMutator,
  );
}

FitModuleItem? _resolveStoredModule(FitStorage fit, native.OutSlotType slotType, int index) =>
    switch (slotType) {
      native.OutSlotType_High() => fit.body.slots.high.getOrNull(index)?.toNullable(),
      native.OutSlotType_Medium() => fit.body.slots.medium.getOrNull(index)?.toNullable(),
      native.OutSlotType_Low() => fit.body.slots.low.getOrNull(index)?.toNullable(),
      native.OutSlotType_Rig() => fit.body.slots.rig.getOrNull(index)?.toNullable(),
      native.OutSlotType_SubSystem() => fit.body.slots.subsystem.getOrNull(index)?.toNullable(),
      native.OutSlotType_Service() => fit.body.slots.service.getOrNull(index)?.toNullable(),
      _ => null,
    };

String _formatDynamicValue(double value) {
  if (value.abs() >= 1000) {
    return value.toStringAsFixed(1);
  }
  if (value.abs() >= 100) {
    return value.toStringAsFixed(2);
  }
  return value.toStringAsFixed(3);
}

String? _resolveLocalization(WidgetRef ref, LocalizationID? localization) {
  if (localization == null) return null;
  final locale = ref.watch(localeProvider).name;
  return watchLocalizedName(ref, id: localization.id, locale: locale);
}

String? _attributeLocalizedName(WidgetRef ref, DogmaAttribute? attribute) {
  if (attribute == null || !attribute.hasDisplayName()) return null;
  final localized = _resolveLocalization(ref, attribute.displayName);
  if (localized?.trim().isNotEmpty ?? false) return localized;
  return null;
}

String? _attributeDisplayName(WidgetRef ref, DogmaAttribute? attribute) {
  final localized = _attributeLocalizedName(ref, attribute);
  if (localized != null) return localized;
  if (attribute == null) return null;
  if (attribute.name.isNotEmpty) return attribute.name;
  return null;
}

String _attributeDebugIdentifier(int attributeId, DogmaAttribute? attribute) {
  final name = attribute?.name.trim() ?? "";
  return name.isEmpty ? "∷[$attributeId]" : "∷$name[$attributeId]";
}

String _formatItemDetailDogmaValue(
  BuildContext context,
  WidgetRef ref,
  DogmaUnit? unit,
  double value,
) => formatDogmaUnitValue(
  context,
  ref,
  unit,
  value,
  resolveGroupId: (groupId) => _resolveGroupName(ref, groupId),
  resolveTypeId: (typeId) => _resolveTypeName(ref, typeId),
  resolveAttributeId: (attributeId) => _resolveAttributeName(ref, attributeId),
);

String? _resolveGroupName(WidgetRef ref, int groupId) {
  final group = ref.watch(repoCollectionProvider.select((c) => c?.getGroup(groupId)));
  if (group == null) return null;
  return _resolveLocalization(ref, group.groupName);
}

String? _resolveAttributeName(WidgetRef ref, int attributeId) {
  final attribute = ref.watch(
    repoCollectionProvider.select((c) => c?.getDogmaAttribute(attributeId)),
  );
  return _attributeDisplayName(ref, attribute);
}

_ValueTone? _attributeDeltaTone({
  required DogmaAttribute? attribute,
  required double baseValue,
  required double currentValue,
}) {
  final delta = currentValue - baseValue;
  if (delta == 0) {
    return null;
  }
  final highIsGood = attribute?.highIsGood ?? true;
  final positiveIsGood = highIsGood;
  if (delta > 0) {
    return positiveIsGood ? _ValueTone.positive : _ValueTone.negative;
  }
  return positiveIsGood ? _ValueTone.negative : _ValueTone.positive;
}

Color _toneColor(BuildContext context, _ValueTone? tone) => switch (tone) {
  _ValueTone.positive => Colors.green.shade700,
  _ValueTone.negative => Colors.red.shade700,
  null => context.theme.colorScheme.onSurface,
};

Color _toneBackground(BuildContext context, _ValueTone? tone) => switch (tone) {
  _ValueTone.positive => Colors.green.withValues(alpha: 0.08),
  _ValueTone.negative => Colors.red.withValues(alpha: 0.08),
  null => context.theme.colorScheme.surfaceContainerHighest,
};

double? _staticAttributeValue(pb_types.Type? type, int attributeId) {
  if (type == null) return null;
  for (final attribute in type.dogmaAttributes) {
    if (attribute.dogmaAttributeId == attributeId) return attribute.value;
  }
  return null;
}

bool _hasSlotSummary(WidgetRef ref, int typeId) {
  final ship = ref.watch(repoCollectionProvider.select((c) => c?.getShip(typeId)));
  final subsystem = ref.watch(repoCollectionProvider.select((c) => c?.getSubsystem(typeId)));
  final slots = ref.watch(repoCollectionProvider.select((c) => c?.slots));
  if (ship != null || subsystem != null) return true;
  return slots != null && _hasRenderedSlotClass(slots, typeId);
}

bool _hasRenderedSlotClass(Slots slots, int typeId) =>
    slots.highSlots.containsKey(typeId) ||
    slots.mediumSlots.containsKey(typeId) ||
    slots.lowSlots.containsKey(typeId) ||
    slots.rigSlots.containsKey(typeId);

String? _renderedSlotClassLabel(BuildContext? context, Slots slots, int typeId) {
  if (slots.highSlots.containsKey(typeId)) {
    return context?.l10n.highSlot;
  }
  if (slots.mediumSlots.containsKey(typeId)) {
    return context?.l10n.midSlot;
  }
  if (slots.lowSlots.containsKey(typeId)) {
    return context?.l10n.lowSlot;
  }
  if (slots.rigSlots.containsKey(typeId)) {
    return context?.l10n.rigSlot;
  }
  return null;
}

native.Item? _resolveNativeItem(native.Ship ship, ItemDetailFitReference reference) {
  native.Item? base = switch (reference.kind) {
    ItemDetailFitObjectKind.hull => ship.hull,
    ItemDetailFitObjectKind.module => _firstWhereOrNull(
      ship.modules,
      (item) => item.slot.slotType == reference.slotType && item.slot.index == reference.index,
    ),
    ItemDetailFitObjectKind.implant => _firstWhereOrNull(
      ship.implants,
      (item) => item.slot.index == reference.index,
    ),
    ItemDetailFitObjectKind.booster => _firstWhereOrNull(
      ship.boosters,
      (item) => item.slot.index == reference.index,
    ),
  };
  if (reference.inspectCharge) {
    base = base?.charge;
  }
  return base;
}

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) predicate) {
  for (final value in values) {
    if (predicate(value)) return value;
  }
  return null;
}

List<_InspectableAttribute> _collectInspectableAttributes(
  AppLocalizations l10n,
  WidgetRef ref,
  pb_types.Type type,
  native.Item? item,
) {
  final currentAttributeIds = item?.attributes.keys.toSet() ?? const <int>{};
  final allIds =
      <int>{
          ...type.dogmaAttributes.map((attribute) => attribute.dogmaAttributeId),
          ...currentAttributeIds,
        }
        ..removeAll(_requiredSkillAttributeIds)
        ..removeAll(_requiredSkillLevelAttributeIds)
        ..removeWhere((attributeId) => attributeId < 0);

  final debugView = ref.watch(attributeDebugViewProvider);
  final attributes = <_InspectableAttribute>[];
  for (final attributeId in allIds) {
    final metadata = ref.watch(
      repoCollectionProvider.select((c) => c?.getDogmaAttribute(attributeId)),
    );
    if (!debugView && (metadata == null || !metadata.published)) continue;
    final staticValue = _staticAttributeValue(type, attributeId) ?? metadata?.defaultValue ?? 0;
    final currentValue = item?.attributes[attributeId]?.value;
    final shouldDisplay =
        debugView ||
        metadata == null ||
        metadata.displayWhenZero ||
        staticValue != 0 ||
        (currentValue != null && currentValue != 0);
    if (!shouldDisplay) continue;

    final unit = metadata?.hasUnitId() ?? false
        ? ref.watch(repoCollectionProvider.select((c) => c?.getDogmaUnit(metadata!.unitId)))
        : null;
    final localizedName = _attributeLocalizedName(ref, metadata);
    final String displayName;
    String? debugSubtitle;
    if (debugView) {
      final identifier = _attributeDebugIdentifier(attributeId, metadata);
      if (localizedName != null) {
        displayName = localizedName;
        debugSubtitle = identifier;
      } else {
        displayName = identifier;
      }
    } else {
      displayName =
          _attributeDisplayName(ref, metadata) ??
          l10n.fallbackAttributeName(attributeId: attributeId);
    }
    attributes.add(
      _InspectableAttribute(
        attributeId: attributeId,
        attribute: metadata,
        displayName: displayName,
        staticValue: staticValue,
        currentValue: currentValue,
        unit: unit,
        debugSubtitle: debugSubtitle,
      ),
    );
  }

  attributes.sort((a, b) {
    final leftCategory = a.attribute?.categoryId ?? -1;
    final rightCategory = b.attribute?.categoryId ?? -1;
    final categoryCompare = leftCategory.compareTo(rightCategory);
    if (categoryCompare != 0) {
      return categoryCompare;
    }
    return a.attributeId.compareTo(b.attributeId);
  });
  return attributes;
}

String _formatCompactNumber(double value) {
  final abs = value.abs();
  if (abs >= 1000) return value.toStringAsFixed(0);
  if (abs >= 100) return value.toStringAsFixed(1);
  if (abs >= 10) return value.toStringAsFixed(2);
  if (abs >= 1) {
    var formatted = value.toStringAsFixed(3);
    while (formatted.contains(".") && formatted.endsWith("0")) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    return formatted.endsWith(".") ? formatted.substring(0, formatted.length - 1) : formatted;
  }
  return value.toStringAsPrecision(4);
}

String _formatSignedCompactNumber(double value) {
  final prefix = value > 0 ? "+" : "";
  return "$prefix${_formatCompactNumber(value)}";
}

_ModifierValueDisplay _modifierHeadlineValueDisplay(
  BuildContext context,
  native.ModifierSource source,
  double originalValue,
  double appliedValue,
) => source.when(
  effect: (effect) => switch (effect.operator_) {
    native.EffectOperator.preMul || native.EffectOperator.postMul => _ModifierValueDisplay(
      primary: "×${_formatCompactNumber(originalValue)}",
      secondary: _effectivePercentLabel(context, appliedValue * 100),
      explanation: _percentShiftExplanation(context, appliedValue * 100),
    ),
    native.EffectOperator.preDiv || native.EffectOperator.postDiv => _ModifierValueDisplay(
      primary: "÷${_formatCompactNumber(originalValue)}",
      secondary: _effectivePercentLabel(context, appliedValue * 100),
      explanation: _divisionPercentShiftExplanation(context, appliedValue * 100),
    ),
    native.EffectOperator.postPercent => _ModifierValueDisplay(
      primary: "${_formatSignedCompactNumber(originalValue)}%",
      explanation: _percentBonusExplanation(context, originalValue),
    ),
    native.EffectOperator.preAssign || native.EffectOperator.postAssign => _ModifierValueDisplay(
      primary: "=${_formatCompactNumber(originalValue)}",
      explanation: context.l10n.itemDetailModifierSetAttribute(
        value: _formatCompactNumber(originalValue),
      ),
    ),
    native.EffectOperator.modAdd => _ModifierValueDisplay(
      primary: "+${_formatCompactNumber(originalValue)}",
      explanation: context.l10n.itemDetailModifierAddsAttribute(
        value: _formatCompactNumber(originalValue),
      ),
    ),
    native.EffectOperator.modSub => _ModifierValueDisplay(
      primary: "-${_formatCompactNumber(originalValue)}",
      explanation: context.l10n.itemDetailModifierSubtractsAttribute(
        value: _formatCompactNumber(originalValue),
      ),
    ),
  },
  buff: (_) => _ModifierValueDisplay(primary: _formatSignedCompactNumber(appliedValue)),
);

_ModifierValueDisplay _modifierSourceValueDisplay(
  BuildContext context,
  native.ModifierSource source,
  double originalValue,
) => source.when(
  effect: (effect) => switch (effect.operator_) {
    native.EffectOperator.preMul || native.EffectOperator.postMul => _ModifierValueDisplay(
      primary: "×${_formatCompactNumber(originalValue)}",
    ),
    native.EffectOperator.preDiv || native.EffectOperator.postDiv => _ModifierValueDisplay(
      primary: "÷${_formatCompactNumber(originalValue)}",
    ),
    native.EffectOperator.postPercent => _ModifierValueDisplay(
      primary: "${_formatSignedCompactNumber(originalValue)}%",
    ),
    native.EffectOperator.preAssign || native.EffectOperator.postAssign => _ModifierValueDisplay(
      primary: "=${_formatCompactNumber(originalValue)}",
    ),
    native.EffectOperator.modAdd => _ModifierValueDisplay(
      primary: "+${_formatCompactNumber(originalValue)}",
    ),
    native.EffectOperator.modSub => _ModifierValueDisplay(
      primary: "-${_formatCompactNumber(originalValue)}",
    ),
  },
  buff: (_) => _ModifierValueDisplay(primary: _formatSignedCompactNumber(originalValue)),
);

_ModifierValueDisplay _modifierAppliedValueDisplay(
  BuildContext context,
  native.ModifierSource source,
  double value,
) => source.when(
  effect: (effect) => switch (effect.operator_) {
    native.EffectOperator.preMul ||
    native.EffectOperator.postMul => _factorStageValueDisplay(context, value),
    native.EffectOperator.preDiv ||
    native.EffectOperator.postDiv => _dividerStageValueDisplay(context, value),
    native.EffectOperator.postPercent => _ModifierValueDisplay(
      primary: "${_formatSignedCompactNumber(value * 100)}%",
      explanation: _percentBonusExplanation(context, value * 100),
    ),
    native.EffectOperator.preAssign || native.EffectOperator.postAssign => _ModifierValueDisplay(
      primary: "=${_formatCompactNumber(value)}",
      explanation: context.l10n.itemDetailModifierSetAttribute(value: _formatCompactNumber(value)),
    ),
    native.EffectOperator.modAdd || native.EffectOperator.modSub => _ModifierValueDisplay(
      primary: _formatSignedCompactNumber(value),
      explanation: value >= 0
          ? context.l10n.itemDetailModifierAddsAttribute(value: _formatCompactNumber(value))
          : context.l10n.itemDetailModifierSubtractsAttribute(
              value: _formatCompactNumber(value.abs()),
            ),
    ),
  },
  buff: (_) => _ModifierValueDisplay(primary: _formatSignedCompactNumber(value)),
);

_ModifierValueDisplay _factorStageValueDisplay(BuildContext context, double value) {
  final factor = 1.0 + value;
  final effectivePercent = value * 100;
  return _ModifierValueDisplay(
    primary: "${_formatSignedCompactNumber(effectivePercent)}%",
    secondary: "×${_formatCompactNumber(factor)}",
    explanation: _percentShiftExplanation(context, effectivePercent),
  );
}

_ModifierValueDisplay _dividerStageValueDisplay(BuildContext context, double value) {
  final divisor = value <= -1 ? null : 1.0 / (1.0 + value);
  final effectivePercent = value * 100;
  return _ModifierValueDisplay(
    primary: "${_formatSignedCompactNumber(effectivePercent)}%",
    secondary: divisor == null ? null : "÷${_formatCompactNumber(divisor)}",
    explanation: _divisionPercentShiftExplanation(context, effectivePercent),
  );
}

String _effectivePercentLabel(BuildContext context, double effectivePercent) => context.l10n
    .itemDetailModifierEffectivePercent(value: _formatSignedCompactNumber(effectivePercent));

String _percentShiftExplanation(BuildContext context, double effectivePercent) {
  final absolutePercent = _formatCompactNumber(effectivePercent.abs());
  return effectivePercent >= 0
      ? context.l10n.itemDetailModifierIncreaseCurrentValue(value: absolutePercent)
      : context.l10n.itemDetailModifierReduceCurrentValue(value: absolutePercent);
}

String _divisionPercentShiftExplanation(BuildContext context, double effectivePercent) {
  final absolutePercent = _formatCompactNumber(effectivePercent.abs());
  return effectivePercent >= 0
      ? context.l10n.itemDetailModifierIncreaseCurrentValueAfterDivision(value: absolutePercent)
      : context.l10n.itemDetailModifierReduceCurrentValueAfterDivision(value: absolutePercent);
}

String _percentBonusExplanation(BuildContext context, double percentValue) => percentValue >= 0
    ? context.l10n.itemDetailModifierAppliesBonusPercent(value: _formatCompactNumber(percentValue))
    : context.l10n.itemDetailModifierAppliesReductionPercent(
        value: _formatCompactNumber(percentValue.abs()),
      );

_ValueTone? _modifierValueTone(
  DogmaAttribute? inspectedAttribute,
  native.ModifierSource source,
  double value,
) {
  final delta = source.when(
    effect: (effect) => switch (effect.operator_) {
      native.EffectOperator.preAssign || native.EffectOperator.postAssign => null,
      native.EffectOperator.preMul ||
      native.EffectOperator.postMul ||
      native.EffectOperator.preDiv ||
      native.EffectOperator.postDiv ||
      native.EffectOperator.postPercent ||
      native.EffectOperator.modAdd ||
      native.EffectOperator.modSub => value,
    },
    buff: (_) => value,
  );
  if (delta == null || delta == 0) return null;
  final highIsGood = inspectedAttribute?.highIsGood ?? true;
  if (delta > 0) {
    return highIsGood ? _ValueTone.positive : _ValueTone.negative;
  }
  return highIsGood ? _ValueTone.negative : _ValueTone.positive;
}

String _effectOperatorLabel(BuildContext context, native.EffectOperator operator) =>
    switch (operator) {
      native.EffectOperator.preAssign => context.l10n.itemDetailEffectOperatorPreAssign,
      native.EffectOperator.preMul => context.l10n.itemDetailEffectOperatorPreMul,
      native.EffectOperator.preDiv => context.l10n.itemDetailEffectOperatorPreDiv,
      native.EffectOperator.modAdd => context.l10n.itemDetailEffectOperatorAdd,
      native.EffectOperator.modSub => context.l10n.itemDetailEffectOperatorSub,
      native.EffectOperator.postMul => context.l10n.itemDetailEffectOperatorPostMul,
      native.EffectOperator.postDiv => context.l10n.itemDetailEffectOperatorPostDiv,
      native.EffectOperator.postPercent => context.l10n.itemDetailEffectOperatorPercent,
      native.EffectOperator.postAssign => context.l10n.itemDetailEffectOperatorPostAssign,
    };

String _traitSectionLabel(
  WidgetRef ref,
  BuildContext context,
  pb_types.Type_TraitSection section,
) => switch (section.kind) {
  pb_types.Type_TraitSectionKind.SKILL when section.hasSkillTypeId() => _traitSectionSkillLabel(
    ref,
    context,
    section.skillTypeId,
  ),
  pb_types.Type_TraitSectionKind.ROLE => context.l10n.itemDetailTraitRoleBonuses,
  pb_types.Type_TraitSectionKind.MISC => context.l10n.itemDetailTraitMiscBonuses,
  _ => context.l10n.itemDetailTraits,
};

String _traitSectionSkillLabel(WidgetRef ref, BuildContext context, int skillTypeId) {
  final skillName = _resolveTypeName(ref, skillTypeId) ?? "Type $skillTypeId";
  final localized = context.l10n.itemDetailTraitPerLevel(skillName: skillName);
  return localized.replaceFirst(skillName, '<a href="showinfo:$skillTypeId">$skillName</a>');
}

String _traitEntryMarkup(WidgetRef ref, BuildContext context, pb_types.Type_TraitEntry entry) {
  final text = _resolveLocalization(ref, entry.text) ?? "LOC[${entry.text.id}]";
  if (!entry.hasBonus()) return text;

  final unit = entry.hasUnitId()
      ? ref.watch(repoCollectionProvider.select((c) => c?.getDogmaUnit(entry.unitId)))
      : null;
  return "${_formatItemDetailDogmaValue(context, ref, unit, entry.bonus)} $text";
}

String? _resolveTypeName(WidgetRef ref, int typeId) {
  final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
  if (type == null) return null;
  return _resolveLocalization(ref, type.typeName);
}

String _modifierSourceLabel(
  BuildContext context,
  WidgetRef ref,
  FitStorage? fit,
  native.Ship? emulated,
  native.ModifierSource source,
) => source.when(
  effect: (effect) => switch (effect.source) {
    native.FitObject_Ship() =>
      _resolveTypeName(ref, fit?.body.shipTypeId ?? 0) ?? context.l10n.itemDetailModifierSourceShip,
    native.FitObject_Item(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.modules,
      field0.toInt(),
      fallback: context.l10n.itemDetailModifierSourceModule(index: field0.toInt() + 1),
    ),
    native.FitObject_Implant(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.implants,
      field0.toInt(),
      fallback: context.l10n.itemDetailModifierSourceImplant(index: field0.toInt() + 1),
    ),
    native.FitObject_Booster(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.boosters,
      field0.toInt(),
      fallback: context.l10n.itemDetailModifierSourceBooster(index: field0.toInt() + 1),
    ),
    native.FitObject_Skill(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.skills,
      field0.toInt(),
      fallback: context.l10n.itemDetailModifierSourceSkill(index: field0.toInt() + 1),
    ),
    native.FitObject_Charge(:final field0) => context.l10n.itemDetailModifierSourceCharge(
      index: field0.toInt() + 1,
    ),
    native.FitObject_Character() => context.l10n.itemDetailModifierSourceCharacter,
    native.FitObject_Structure() => context.l10n.itemDetailModifierSourceStructure,
    native.FitObject_Target() => context.l10n.itemDetailModifierSourceTarget,
  },
  buff: (buffId) => context.l10n.itemDetailBuffSource(buffId: buffId),
);

String _resolveNativeIndexedObjectName(
  WidgetRef ref,
  FitStorage? fit,
  List<native.Item>? items,
  int index, {
  required String fallback,
}) {
  if (items == null || index < 0 || index >= items.length) return fallback;
  final typeId = _resolveNativeItemTypeId(fit, items[index]);
  return typeId == null ? fallback : (_resolveTypeName(ref, typeId) ?? fallback);
}

int? _resolveNativeItemTypeId(FitStorage? fit, native.Item item) => switch (item.itemId) {
  native_storage.ItemID_Item(:final field0) => field0,
  native_storage.ItemID_Dynamic(:final field0) => fit?.dynamicRegistry.dynamicItems[field0]?.typeId,
};

String _effectCategoryLabel(BuildContext context, native.EffectCategory category) =>
    switch (category) {
      native.EffectCategory.passive => context.l10n.itemDetailEffectCategoryPassive,
      native.EffectCategory.online => context.l10n.itemDetailEffectCategoryOnline,
      native.EffectCategory.active => context.l10n.itemDetailEffectCategoryActive,
      native.EffectCategory.overload => context.l10n.itemDetailEffectCategoryOverload,
      native.EffectCategory.target => context.l10n.itemDetailEffectCategoryTarget,
      native.EffectCategory.area => context.l10n.itemDetailEffectCategoryArea,
      native.EffectCategory.dungeon => context.l10n.itemDetailEffectCategoryDungeon,
      native.EffectCategory.system => context.l10n.itemDetailEffectCategorySystem,
    };
