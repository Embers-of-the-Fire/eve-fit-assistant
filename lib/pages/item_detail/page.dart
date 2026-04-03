import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/components/localized_text.dart";
import "package:eve_fit_assistant/data/proto/dogma_attributes.pb.dart";
import "package:eve_fit_assistant/data/proto/dogma_units.pb.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/data/proto/utils.pb.dart" show LocalizationID;
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/service/localization.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:html/parser.dart" as html_parser;

const List<int> _requiredSkillAttributeIds = [182, 183, 184, 1285, 1289, 1290];
const List<int> _requiredSkillLevelAttributeIds = [277, 278, 279, 1286, 1287, 1288];

enum ItemDetailFitObjectKind { hull, module, implant, booster }

class ItemDetailFitReference {
  const ItemDetailFitReference({
    required this.fitId,
    required this.kind,
    this.index,
    this.inspectCharge = false,
  });

  const ItemDetailFitReference.module({
    required String fitId,
    required int index,
    bool inspectCharge = false,
  }) : this(
         fitId: fitId,
         kind: ItemDetailFitObjectKind.module,
         index: index,
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
    final description = type.hasDescription()
        ? _normalizeRichText(_resolveLocalization(ref, type.description) ?? "")
        : null;

    return Layout(
      title: itemName,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(type: type, fitReference: fitReference),
          const SizedBox(height: 12),
          _ClassificationCard(type: type),
          if (description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: context.l10n.itemDetailDescription,
              child: SelectableText(description!),
            ),
          ],
          if (type.traitSections.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TraitCard(type: type, fitReference: fitReference),
          ],
          if (type.requiredSkills.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RequirementsCard(type: type, fitReference: fitReference),
          ],
          if (_hasSlotSummary(ref, typeId)) ...[
            const SizedBox(height: 12),
            _SlotSummaryCard(typeId: typeId),
          ],
          if (attributes.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttributesCard(
              typeId: typeId,
              fitReference: fitReference,
              attributes: attributes,
              resolvedItem: resolvedItem,
            ),
          ],
        ],
      ),
    );
  }
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
                  Text(
                    _normalizeRichText(attribute.description),
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
                          : _formatAttributeValue(ref, attribute, unit, staticValue),
                    ),
                    _ValueChip(
                      label: context.l10n.itemDetailAttributeCurrentValue,
                      value: current?.value == null
                          ? context.l10n.itemDetailUnavailable
                          : _formatAttributeValue(ref, attribute, unit, current!.value!),
                    ),
                    if (staticValue != null && current?.value != null)
                      _ValueChip(
                        label: context.l10n.itemDetailAttributeDelta,
                        value: _formatSignedValue(
                          ref,
                          attribute,
                          unit,
                          current!.value! - staticValue,
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
                      _TagChip(
                        label: fitReference == null
                            ? context.l10n.itemDetailStaticData
                            : context.l10n.itemDetailFitAware,
                      ),
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
          Text(
            _traitSectionTitle(context, ref, section),
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
                    child: Text(
                      _traitEntryLabel(ref, entry),
                      style: context.theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          if (section.hasSkillTypeId()) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showItemDetailPage(
                  context,
                  typeId: section.skillTypeId,
                  fitReference: fitReference,
                ),
                icon: const Icon(Icons.open_in_new),
                label: TypeNameText(typeId: section.skillTypeId),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class _RequirementsCard extends ConsumerWidget {
  const _RequirementsCard({required this.type, required this.fitReference});

  final pb_types.Type type;
  final ItemDetailFitReference? fitReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SectionCard(
    title: context.l10n.itemDetailRequirements,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final requirement in type.requiredSkills)
          _SkillRequirementNode(requirement: requirement, fitReference: fitReference, depth: 0),
      ],
    ),
  );
}

class _SkillRequirementNode extends ConsumerWidget {
  const _SkillRequirementNode({
    required this.requirement,
    required this.fitReference,
    required this.depth,
  });

  final pb_types.Type_SkillRequirement requirement;
  final ItemDetailFitReference? fitReference;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillType = ref.watch(bundleCollectionGetTypeProvider(requirement.skillTypeId));
    final List<pb_types.Type_SkillRequirement> childRequirements =
        skillType?.requiredSkills.toList() ?? const [];
    final title = skillType == null
        ? Text("Type ${requirement.skillTypeId}")
        : TypeNameText(typeId: requirement.skillTypeId);

    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 8),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        dense: true,
        title: Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: 8),
            _LevelPips(level: requirement.level),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => showItemDetailPage(
                context,
                typeId: requirement.skillTypeId,
                fitReference: fitReference,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
          ],
        ),
        children: [
          for (final child in childRequirements)
            _SkillRequirementNode(requirement: child, fitReference: fitReference, depth: depth + 1),
        ],
      ),
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
      if (slots.highSlots.containsKey(typeId)) {
        rows.add(_DataRow(label: context.l10n.itemDetailSlotClass, value: context.l10n.highSlot));
      } else if (slots.mediumSlots.containsKey(typeId)) {
        rows.add(_DataRow(label: context.l10n.itemDetailSlotClass, value: context.l10n.midSlot));
      } else if (slots.lowSlots.containsKey(typeId)) {
        rows.add(_DataRow(label: context.l10n.itemDetailSlotClass, value: context.l10n.lowSlot));
      } else if (slots.rigSlots.containsKey(typeId)) {
        rows.add(_DataRow(label: context.l10n.itemDetailSlotClass, value: context.l10n.rigSlot));
      }
    }

    return _SectionCard(
      title: context.l10n.itemDetailFitting,
      child: Column(children: rows),
    );
  }
}

class _AttributesCard extends ConsumerWidget {
  const _AttributesCard({
    required this.typeId,
    required this.fitReference,
    required this.attributes,
    required this.resolvedItem,
  });

  final int typeId;
  final ItemDetailFitReference? fitReference;
  final List<_InspectableAttribute> attributes;
  final native.Item? resolvedItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _SectionCard(
    title: context.l10n.itemDetailAttributes,
    child: Column(
      children: [
        for (final attribute in attributes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(attribute.displayName),
            subtitle: attribute.currentValue == null
                ? null
                : Text(
                    context.l10n.itemDetailAttributeBaseAndCurrent(
                      base: _formatAttributeValue(
                        ref,
                        attribute.attribute,
                        attribute.unit,
                        attribute.staticValue,
                      ),
                      current: _formatAttributeValue(
                        ref,
                        attribute.attribute,
                        attribute.unit,
                        attribute.currentValue!,
                      ),
                    ),
                  ),
            trailing: Text(
              _formatAttributeValue(
                ref,
                attribute.attribute,
                attribute.unit,
                attribute.currentValue ?? attribute.staticValue,
              ),
              textAlign: TextAlign.end,
            ),
            onTap: () => showAttributeDetailPage(
              context,
              typeId: typeId,
              attributeId: attribute.attributeId,
              fitReference: fitReference,
            ),
          ),
      ],
    ),
  );
}

class _ModifierTile extends ConsumerWidget {
  const _ModifierTile({required this.modifier, required this.fit, required this.emulated});

  final native.ModifierTracker modifier;
  final FitStorage? fit;
  final native.Ship? emulated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceLabel = _modifierSourceLabel(ref, fit, emulated, modifier.source);
    final detail = modifier.source.when(
      effect: (effect) {
        final attribute = ref.watch(
          bundleCollectionGetDogmaAttributeProvider(effect.sourceAttributeId),
        );
        final attributeName =
            _attributeDisplayName(ref, attribute) ?? "Attribute ${effect.sourceAttributeId}";
        return "${_effectCategoryLabel(effect.sourceCategory)} - $attributeName";
      },
      buff: (buffId) => context.l10n.itemDetailBuffSource(buffId: buffId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(sourceLabel, style: context.theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(detail),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ValueChip(
              label: context.l10n.itemDetailOriginal,
              value: _formatCompactNumber(modifier.originalValue),
            ),
            _ValueChip(
              label: context.l10n.itemDetailNormalized,
              value: _formatCompactNumber(modifier.normalizedValue),
            ),
            _ValueChip(
              label: context.l10n.itemDetailPenalized,
              value: _formatCompactNumber(modifier.penalizedValue),
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
  const _ValueChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: context.theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.theme.textTheme.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: context.theme.textTheme.bodyMedium),
      ],
    ),
  );
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
        width: 10,
        height: 10,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? context.theme.colorScheme.primary : Colors.transparent,
          border: Border.all(color: context.theme.colorScheme.primary),
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

String? _resolveLocalization(WidgetRef ref, LocalizationID? localization) => switch (localization) {
  null => null,
  _ => ref.watch(localizationProvider(localization.id)),
};

String _normalizeRichText(String input) => (html_parser.parseFragment(input).text ?? "").trim();

String? _attributeDisplayName(WidgetRef ref, DogmaAttribute? attribute) {
  if (attribute == null) return null;
  if (attribute.hasDisplayName()) {
    final localized = _resolveLocalization(ref, attribute.displayName);
    if (localized?.trim().isNotEmpty ?? false) return localized;
  }
  if (attribute.name.isNotEmpty) return attribute.name;
  return null;
}

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
  if (slots == null) return false;
  return slots.highSlots.containsKey(typeId) ||
      slots.mediumSlots.containsKey(typeId) ||
      slots.lowSlots.containsKey(typeId) ||
      slots.rigSlots.containsKey(typeId) ||
      slots.subsystemSlots.containsKey(typeId) ||
      slots.serviceSlots.containsKey(typeId) ||
      slots.implantSlots.containsKey(typeId) ||
      slots.boosterSlots.containsKey(typeId);
}

native.Item? _resolveNativeItem(native.Ship ship, ItemDetailFitReference reference) {
  native.Item? base = switch (reference.kind) {
    ItemDetailFitObjectKind.hull => ship.hull,
    ItemDetailFitObjectKind.module => _firstWhereOrNull(
      ship.modules,
      (item) => item.slot.index == reference.index,
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

  attributes.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return attributes;
}

String _formatAttributeValue(
  WidgetRef ref,
  DogmaAttribute? attribute,
  DogmaUnit? unit,
  double value,
) {
  final formatted = _formatCompactNumber(value);
  if (unit == null) return formatted;

  final localizedUnit = unit.hasDisplayName() ? _resolveLocalization(ref, unit.displayName) : null;
  final unitLabel = localizedUnit?.trim().isNotEmpty ?? false ? localizedUnit! : unit.name;
  final normalizedUnit = unitLabel.toLowerCase();
  if (unitLabel.contains("%") || normalizedUnit.contains("percent")) {
    return "${_formatCompactNumber(value)}%";
  }
  if (normalizedUnit == "bool") {
    return value == 0 ? "False" : "True";
  }
  if (unitLabel.isEmpty) return formatted;
  return "$formatted $unitLabel";
}

String _formatSignedValue(WidgetRef ref, DogmaAttribute? attribute, DogmaUnit? unit, double value) {
  final prefix = value >= 0 ? "+" : "";
  return "$prefix${_formatAttributeValue(ref, attribute, unit, value)}";
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

String _traitSectionTitle(
  BuildContext context,
  WidgetRef ref,
  pb_types.Type_TraitSection section,
) => switch (section.kind) {
  pb_types.Type_TraitSectionKind.SKILL when section.hasSkillTypeId() =>
    context.l10n.itemDetailTraitPerLevel(
      skillName: _resolveTypeName(ref, section.skillTypeId) ?? "Type ${section.skillTypeId}",
    ),
  pb_types.Type_TraitSectionKind.ROLE => context.l10n.itemDetailTraitRoleBonuses,
  pb_types.Type_TraitSectionKind.MISC => context.l10n.itemDetailTraitMiscBonuses,
  _ => context.l10n.itemDetailTraits,
};

String _traitEntryLabel(WidgetRef ref, pb_types.Type_TraitEntry entry) {
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
  WidgetRef ref,
  FitStorage? fit,
  native.Ship? emulated,
  native.ModifierSource source,
) => source.when(
  effect: (effect) => switch (effect.source) {
    native.FitObject_Ship() => _resolveTypeName(ref, fit?.body.shipTypeId ?? 0) ?? "Ship",
    native.FitObject_Item(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.modules,
      field0.toInt(),
      fallback: "Module ${field0.toInt() + 1}",
    ),
    native.FitObject_Implant(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.implants,
      field0.toInt(),
      fallback: "Implant ${field0.toInt() + 1}",
    ),
    native.FitObject_Booster(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.boosters,
      field0.toInt(),
      fallback: "Booster ${field0.toInt() + 1}",
    ),
    native.FitObject_Skill(:final field0) => _resolveNativeIndexedObjectName(
      ref,
      fit,
      emulated?.skills,
      field0.toInt(),
      fallback: "Skill ${field0.toInt() + 1}",
    ),
    native.FitObject_Charge(:final field0) => "Charge ${field0.toInt() + 1}",
    native.FitObject_Character() => "Character",
    native.FitObject_Structure() => "Structure",
    native.FitObject_Target() => "Target",
  },
  buff: (buffId) => "Buff $buffId",
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

String _effectCategoryLabel(native.EffectCategory category) => switch (category) {
  native.EffectCategory.passive => "Passive",
  native.EffectCategory.online => "Online",
  native.EffectCategory.active => "Active",
  native.EffectCategory.overload => "Overload",
  native.EffectCategory.target => "Target",
  native.EffectCategory.area => "Area",
  native.EffectCategory.dungeon => "Dungeon",
  native.EffectCategory.system => "System",
};
