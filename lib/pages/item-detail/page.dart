import "package:eve_fit_assistant/components/description_text.dart";
import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart";
import "package:eve_fit_assistant/data/proto/fit.pb.dart" show Slots;
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/data/proto/utils.pb.dart" show LocalizationID;
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const List<int> _requiredSkillAttributeIds = [182, 183, 184, 1285, 1289, 1290];
const List<int> _requiredSkillLevelAttributeIds = [277, 278, 279, 1286, 1287, 1288];
const int _itemDetailTabCount = 3;

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
    final type = ref.watch(bundleCollectionGetTypeProvider(typeId));
    if (type == null) {
      return Layout(
        title: "Type $typeId",
        child: Center(child: Text("Unknown Type[$typeId]")),
      );
    }

    final itemName = _resolveLocalization(ref, type.typeName) ?? "Type $typeId";
    final fit = fitReference == null ? null : ref.watch(fitProvider(fitReference!.fitId));
    final emulated = fitReference == null
        ? null
        : ref.watch(nativeEmulatedShipProvider(fitReference!.fitId));
    final resolvedItem = switch ((fitReference, fit?.isInitialized ?? false, emulated)) {
      (final ItemDetailFitReference reference?, true, final native.Ship ship?) =>
        _resolveNativeItem(ship, reference),
      _ => null,
    };

    final attributes = _collectInspectableAttributes(ref, type, resolvedItem);
    final description = type.hasDescription() ? _resolveLocalization(ref, type.description) : null;

    return Layout(
      title: itemName,
      child: _ItemDetailColumns(
        typeId: typeId,
        type: type,
        fitReference: fitReference,
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
    required this.description,
    required this.attributes,
    required this.resolvedItem,
  });

  final int typeId;
  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;
  final String? description;
  final List<_InspectableAttribute> attributes;
  final native.Item? resolvedItem;

  @override
  Widget build(BuildContext context) {
    final paneCount = switch (columnCount(context)) {
      >= _itemDetailTabCount => _itemDetailTabCount,
      final count => count,
    };

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
    required this.description,
    required this.attributes,
  });

  final int initialIndex;
  final int typeId;
  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;
  final String? description;
  final List<_InspectableAttribute> attributes;

  @override
  State<_ItemDetailTabPane> createState() => _ItemDetailTabPaneState();
}

class _ItemDetailTabPaneState extends State<_ItemDetailTabPane>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      initialIndex: widget.initialIndex,
      length: _itemDetailTabCount,
      vsync: this,
    );
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
    final type = ref.watch(bundleCollectionGetTypeProvider(typeId));
    final attribute = ref.watch(bundleCollectionGetDogmaAttributeProvider(attributeId));
    final unit = attribute?.hasUnitId() ?? false
        ? ref.watch(bundleCollectionGetDogmaUnitProvider(attribute!.unitId))
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
    final title = _attributeDisplayName(ref, attribute) ?? "Attribute $attributeId";

    return Layout(
      title: title,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: context.l10n.itemDetailAttributeOverview,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (type != null) ...[
                  Text(
                    context.l10n.itemDetailAttributeType,
                    style: context.theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  TypeNameText(typeId: typeId),
                  const SizedBox(height: 12),
                ],
                if (attribute != null && attribute.description.isNotEmpty) ...[
                  DescriptionText(
                    text: attribute.description,
                    style: context.theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ValueChip(
                      label: context.l10n.itemDetailAttributeBaseValue,
                      value: staticValue == null
                          ? context.l10n.itemDetailUnavailable
                          : _formatAttributeValue(context, ref, attribute, unit, staticValue),
                    ),
                    _ValueChip(
                      label: context.l10n.itemDetailAttributeCurrentValue,
                      value: current?.value == null
                          ? context.l10n.itemDetailUnavailable
                          : _formatAttributeValue(context, ref, attribute, unit, current!.value!),
                      tone: current?.value == null
                          ? null
                          : staticValue == null
                          ? null
                          : _attributeDeltaTone(
                              attribute: attribute,
                              baseValue: staticValue,
                              currentValue: current!.value!,
                            ),
                    ),
                    if (staticValue != null && current?.value != null && !_isBooleanUnit(ref, unit))
                      _ValueChip(
                        label: context.l10n.itemDetailAttributeDelta,
                        value: _formatSignedValue(
                          context,
                          ref,
                          attribute,
                          unit,
                          current!.value! - staticValue,
                        ),
                        tone: _attributeDeltaTone(
                          attribute: attribute,
                          baseValue: staticValue,
                          currentValue: current.value!,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: context.l10n.itemDetailEffectChain,
            child: (current?.trackedModifiers.isNotEmpty ?? false)
                ? Column(
                    children: [
                      for (final modifier in current!.trackedModifiers) ...[
                        _ModifierTile(modifier: modifier, fit: fit?.fit, emulated: emulated),
                        const Divider(height: 16),
                      ],
                    ],
                  )
                : Text(context.l10n.itemDetailNoEffectChain),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaGroup = ref.watch(bundleCollectionGetMetaGroupProvider(type.metaGroupId));
    final group = ref.watch(bundleCollectionGetGroupProvider(type.groupId));

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
    final group = ref.watch(bundleCollectionGetGroupProvider(type.groupId));
    final category = group == null
        ? null
        : ref.watch(bundleCollectionGetCategoryProvider(group.categoryId));
    final marketGroup = type.hasMarketGroupId()
        ? ref.watch(bundleCollectionGetMarketGroupProvider(type.marketGroupId))
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
                      text: _traitEntryMarkup(ref, entry),
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
    final skillType = ref.watch(bundleCollectionGetTypeProvider(widget.requirement.skillTypeId));
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
                    child: hasChildren
                        ? IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() => _expanded = !_expanded),
                            icon: Icon(
                              _expanded ? Icons.expand_more : Icons.chevron_right,
                              size: 18,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: skillType == null
                        ? Text("Type ${widget.requirement.skillTypeId}")
                        : TypeNameText(typeId: widget.requirement.skillTypeId),
                  ),
                  const SizedBox(width: 12),
                  _LevelPips(level: widget.requirement.level),
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
    final ship = ref.watch(bundleCollectionGetShipProvider(typeId));
    final subsystem = ref.watch(bundleCollectionGetSubsystemProvider(typeId));
    final slots = ref.watch(bundleCollectionGetSlotsProvider);

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
            trailing: Text(
              _formatAttributeValue(
                context,
                ref,
                attribute.attribute,
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

class _ModifierTile extends ConsumerWidget {
  const _ModifierTile({required this.modifier, required this.fit, required this.emulated});

  final native.ModifierTracker modifier;
  final FitStorage? fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLabel = _modifierSourceLabel(context, ref, fit, emulated, modifier.source);
    final normalizedDelta = modifier.normalizedValue - modifier.originalValue;
    final penalizedDelta = modifier.penalizedValue - modifier.normalizedValue;
    final netDelta = modifier.penalizedValue - modifier.originalValue;
    final detail = modifier.source.when(
      effect: (effect) {
        final attribute = ref.watch(
          bundleCollectionGetDogmaAttributeProvider(effect.sourceAttributeId),
        );
        final attributeName =
            _attributeDisplayName(ref, attribute) ?? "Attribute ${effect.sourceAttributeId}";
        return "${_effectCategoryLabel(context, effect.sourceCategory)} - ${_effectOperatorLabel(context, effect.operator_)} - $attributeName";
      },
      buff: (buffId) => context.l10n.itemDetailBuffSource(buffId: buffId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(sourceLabel, style: context.theme.textTheme.titleSmall)),
            if (modifier.source is native.ModifierSource_Effect &&
                (modifier.source as native.ModifierSource_Effect).field0.penalty)
              Text(
                context.l10n.itemDetailPenalty,
                style: context.theme.textTheme.labelMedium?.copyWith(color: Colors.red.shade700),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(detail),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _EffectValueText(
                label: context.l10n.itemDetailOriginal,
                value: _formatCompactNumber(modifier.originalValue),
              ),
            ),
            Expanded(
              child: _EffectValueText(
                label: context.l10n.itemDetailNormalized,
                value: _formatCompactNumber(modifier.normalizedValue),
                delta: _formatSignedCompactNumber(normalizedDelta),
                tone: _effectDeltaTone(normalizedDelta),
              ),
            ),
            Expanded(
              child: _EffectValueText(
                label: context.l10n.itemDetailPenalized,
                value: _formatCompactNumber(modifier.penalizedValue),
                delta: _formatSignedCompactNumber(penalizedDelta),
                tone: _effectDeltaTone(penalizedDelta),
              ),
            ),
            Expanded(
              child: _EffectValueText(
                label: context.l10n.itemDetailNet,
                value: _formatSignedCompactNumber(netDelta),
                tone: _effectDeltaTone(netDelta),
              ),
            ),
          ],
        ),
      ],
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
  const _EffectValueText({required this.label, required this.value, this.delta, this.tone});

  final String label;
  final String value;
  final String? delta;
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
        if (delta != null)
          Text(
            delta!,
            style: context.theme.textTheme.labelMedium?.copyWith(
              color: tone == null ? null : color,
            ),
          ),
      ],
    );
  }
}

class _LevelPips extends StatelessWidget {
  const _LevelPips({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(5, (index) {
      final active = index < level;
      return Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: active ? context.theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: active ? context.theme.colorScheme.primary : context.theme.colorScheme.outline,
          ),
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
  });

  final int attributeId;
  final DogmaAttribute? attribute;
  final String displayName;
  final double staticValue;
  final double? currentValue;
  final DogmaUnit? unit;
}

enum _ValueTone { positive, negative }

String? _resolveLocalization(WidgetRef ref, LocalizationID? localization) => switch (localization) {
  null => null,
  _ => ref.watch(localizationProvider(localization.id)),
};

String? _attributeDisplayName(WidgetRef ref, DogmaAttribute? attribute) {
  if (attribute == null) return null;
  if (attribute.hasDisplayName()) {
    final localized = _resolveLocalization(ref, attribute.displayName);
    if (localized?.trim().isNotEmpty ?? false) return localized;
  }
  if (attribute.name.isNotEmpty) return attribute.name;
  return null;
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

_ValueTone? _effectDeltaTone(double delta) {
  if (delta == 0) {
    return null;
  }
  return delta > 0 ? _ValueTone.positive : _ValueTone.negative;
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
  final ship = ref.watch(bundleCollectionGetShipProvider(typeId));
  final subsystem = ref.watch(bundleCollectionGetSubsystemProvider(typeId));
  final slots = ref.watch(bundleCollectionGetSlotsProvider);
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
        ..removeAll(_requiredSkillLevelAttributeIds);

  final attributes = <_InspectableAttribute>[];
  for (final attributeId in allIds) {
    final metadata = ref.watch(bundleCollectionGetDogmaAttributeProvider(attributeId));
    final staticValue = _staticAttributeValue(type, attributeId) ?? metadata?.defaultValue ?? 0;
    final currentValue = item?.attributes[attributeId]?.value;
    final shouldDisplay =
        metadata == null ||
        metadata.displayWhenZero ||
        staticValue != 0 ||
        (currentValue != null && currentValue != 0);
    if (!shouldDisplay) continue;

    final unit = metadata?.hasUnitId() ?? false
        ? ref.watch(bundleCollectionGetDogmaUnitProvider(metadata!.unitId))
        : null;
    attributes.add(
      _InspectableAttribute(
        attributeId: attributeId,
        attribute: metadata,
        displayName: _attributeDisplayName(ref, metadata) ?? "Attribute $attributeId",
        staticValue: staticValue,
        currentValue: currentValue,
        unit: unit,
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

String _formatAttributeValue(
  BuildContext context,
  WidgetRef ref,
  DogmaAttribute? attribute,
  DogmaUnit? unit,
  double value,
) {
  final formatted = _formatCompactNumber(value);
  if (unit == null) return formatted;

  final unitLabel = _unitLabel(ref, unit);
  final normalizedUnit = unitLabel.toLowerCase();
  if (unitLabel.contains("%") || normalizedUnit.contains("percent")) {
    return "${_formatCompactNumber(value)}%";
  }
  if (_isBooleanUnit(ref, unit)) {
    return value == 0 ? context.l10n.itemDetailBooleanFalse : context.l10n.itemDetailBooleanTrue;
  }
  if (unitLabel.isEmpty) return formatted;
  return "$formatted $unitLabel";
}

String _unitLabel(WidgetRef ref, DogmaUnit unit) {
  final localizedUnit = unit.hasDisplayName() ? _resolveLocalization(ref, unit.displayName) : null;
  return localizedUnit?.trim().isNotEmpty ?? false ? localizedUnit! : unit.name;
}

bool _isBooleanUnit(WidgetRef ref, DogmaUnit? unit) {
  if (unit == null) return false;
  return _unitLabel(ref, unit).toLowerCase() == "bool";
}

String _formatSignedValue(
  BuildContext context,
  WidgetRef ref,
  DogmaAttribute? attribute,
  DogmaUnit? unit,
  double value,
) {
  final prefix = value >= 0 ? "+" : "";
  return "$prefix${_formatAttributeValue(context, ref, attribute, unit, value)}";
}

String _formatCompactNumber(double value) {
  final abs = value.abs();
  if (abs >= 1000) return value.toStringAsFixed(0);
  if (abs >= 100) return value.toStringAsFixed(1);
  if (abs >= 10) return value.toStringAsFixed(2);
  if (abs >= 1) {
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r"\.0+$"), "")
        .replaceFirst(RegExp(r"(\.[0-9]*?)0+$"), r"\1");
  }
  return value.toStringAsPrecision(4);
}

String _formatSignedCompactNumber(double value) {
  final prefix = value > 0 ? "+" : "";
  return "$prefix${_formatCompactNumber(value)}";
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

String _traitEntryMarkup(WidgetRef ref, pb_types.Type_TraitEntry entry) {
  final text = _resolveLocalization(ref, entry.text) ?? "LOC[${entry.text.id}]";
  if (!entry.hasBonus()) return text;

  final unit = entry.hasUnitId()
      ? ref.watch(bundleCollectionGetDogmaUnitProvider(entry.unitId))
      : null;
  if (unit == null) return "${_formatCompactNumber(entry.bonus)} $text";
  final unitLabel = unit.hasDisplayName()
      ? _resolveLocalization(ref, unit.displayName) ?? unit.name
      : unit.name;
  if (unitLabel.contains("%") || unitLabel.toLowerCase().contains("percent")) {
    return "${_formatCompactNumber(entry.bonus)}% $text";
  }
  return "${_formatCompactNumber(entry.bonus)} $unitLabel $text";
}

String? _resolveTypeName(WidgetRef ref, int typeId) {
  final type = ref.watch(bundleCollectionGetTypeProvider(typeId));
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
