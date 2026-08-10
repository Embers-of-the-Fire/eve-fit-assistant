part of "../page.dart";

enum _FitIssueSeverity { warning, error }

enum _FitIssueSection {
  tacticalMode,
  high,
  medium,
  low,
  rig,
  subsystem,
  service,
  drone,
  fighter,
  implant,
  booster,
  ship,
}

class _FitIssue {
  const _FitIssue({required this.severity, required this.title, required this.details});

  final _FitIssueSeverity severity;
  final String title;
  final String details;
}

List<_FitIssue> _collectFitIssuesForSection(
  BuildContext context,
  WidgetRef ref,
  FitContext fitContext,
  _FitIssueSection section,
) {
  if (ref.read(repoCollectionProvider) == null) return const [];

  final fit = fitContext.fit;
  final issues = <_FitIssue>[];

  void addItemIssue(FitStorageItemId itemId, String slotName, int position) {
    final labelIndex = position + 1;
    final dynamicId = itemId.dynamicIdOrNull;
    if (dynamicId != null && fit.dynamicRegistry.dynamicItems[dynamicId] == null) {
      issues.add(
        _FitIssue(
          severity: _FitIssueSeverity.error,
          title: context.l10n.fitIssueMissingDynamic(slotName: slotName, index: labelIndex),
          details: "dynamicId=$dynamicId",
        ),
      );
      return;
    }

    final typeId = fitContext.resolveDisplayTypeId(itemId);
    if (typeId == null) return;
    if (ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId))) != null) return;

    issues.add(
      _FitIssue(
        severity: _FitIssueSeverity.error,
        title: context.l10n.fitIssueMissingItemType(slotName: slotName, index: labelIndex),
        details: "typeId=$typeId",
      ),
    );
  }

  void addChargeIssue(Option<FitChargeItem> charge, String slotName, int position) {
    final chargeTypeId = charge.toNullable()?.typeId;
    if (chargeTypeId == null) return;
    if (ref.watch(repoCollectionProvider.select((c) => c?.getType(chargeTypeId))) != null) return;

    issues.add(
      _FitIssue(
        severity: _FitIssueSeverity.warning,
        title: context.l10n.fitIssueMissingChargeType(slotName: slotName, index: position + 1),
        details: "typeId=$chargeTypeId",
      ),
    );
  }

  switch (section) {
    case _FitIssueSection.tacticalMode:
      fit.body.slots.tacticalMode.match(() {}, (typeId) {
        if (ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId))) != null) return;
        issues.add(
          _FitIssue(
            severity: _FitIssueSeverity.error,
            title: context.l10n.fitIssueMissingItemType(
              slotName: context.l10n.tacticalMode,
              index: 1,
            ),
            details: "typeId=$typeId",
          ),
        );
      });
    case _FitIssueSection.high:
      for (final (index, slot) in fit.body.slots.high.mapWithIndex(
        (slot, index) => (index, slot),
      )) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.highSlot, index);
          addChargeIssue(slot.charge, context.l10n.highSlot, index);
        });
      }
    case _FitIssueSection.medium:
      for (final (index, slot) in fit.body.slots.medium.mapWithIndex(
        (slot, index) => (index, slot),
      )) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.midSlot, index);
          addChargeIssue(slot.charge, context.l10n.midSlot, index);
        });
      }
    case _FitIssueSection.low:
      for (final (index, slot) in fit.body.slots.low.mapWithIndex((slot, index) => (index, slot))) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.lowSlot, index);
          addChargeIssue(slot.charge, context.l10n.lowSlot, index);
        });
      }
    case _FitIssueSection.rig:
      for (final (index, slot) in fit.body.slots.rig.mapWithIndex((slot, index) => (index, slot))) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.rigSlot, index);
        });
      }
    case _FitIssueSection.subsystem:
      for (final (index, slot) in fit.body.slots.subsystem.mapWithIndex(
        (slot, index) => (index, slot),
      )) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.subsystemSlot, index);
        });
      }
    case _FitIssueSection.service:
      for (final (index, slot) in fit.body.slots.service.mapWithIndex(
        (slot, index) => (index, slot),
      )) {
        slot.match(() {}, (slot) {
          addItemIssue(slot.itemId, context.l10n.serviceSlot, index);
        });
      }
    case _FitIssueSection.drone:
      for (final (index, slot) in fit.body.drones.mapWithIndex((slot, index) => (index, slot))) {
        addItemIssue(slot.itemId, context.l10n.drone, index);
      }
    case _FitIssueSection.fighter:
      for (final (index, slot) in fit.body.fighters.mapWithIndex((slot, index) => (index, slot))) {
        addItemIssue(slot.itemId, context.l10n.fighter, index);
      }
    case _FitIssueSection.implant:
      for (final (index, slot) in fit.body.implants.mapWithIndex((slot, index) => (index, slot))) {
        addItemIssue(slot.itemId, context.l10n.implantSlot, index);
      }
    case _FitIssueSection.booster:
      for (final slot in fit.body.boosters) {
        addItemIssue(slot.itemId, context.l10n.boosterSlot, slot.index - 1);
      }
    case _FitIssueSection.ship:
      break;
  }

  issues.addAll(_collectNativeValidationIssuesForSection(context, ref, fitContext, section));

  return issues;
}

List<_FitIssue> _collectFitIssuesForSlot(
  BuildContext context,
  WidgetRef ref,
  FitContext fitContext,
  SlotIdentifier slotIdent,
) {
  final slotType = _validationSlotTypeForIdentifier(slotIdent);
  if (slotType == null) return const [];

  return _collectNativeValidationIssues(
    context,
    ref,
    fitContext,
    slotType: slotType,
    index: switch (slotIdent) {
      SlotIdentifierBooster(:final slotId) => slotId,
      _ => slotIdent.asIndexed,
    },
  );
}

List<_FitIssue> _collectNativeValidationIssuesForSection(
  BuildContext context,
  WidgetRef ref,
  FitContext fitContext,
  _FitIssueSection section,
) {
  final slotType = _validationSlotTypeForSection(section);
  if (slotType == null) return const [];

  return _collectNativeValidationIssues(context, ref, fitContext, slotType: slotType, index: null);
}

List<_FitIssue> _collectNativeValidationIssues(
  BuildContext context,
  WidgetRef ref,
  FitContext fitContext, {
  required native_validation.ValidationSlotType slotType,
  required int? index,
}) {
  final validationIssues = fitContext.emulated?.validationIssues ?? const [];

  return validationIssues
      .where((issue) => issue.slotType == slotType && issue.index == index)
      .map((issue) => _localizeNativeValidationIssue(context, ref, issue))
      .toList();
}

_FitIssue _localizeNativeValidationIssue(
  BuildContext context,
  WidgetRef ref,
  native_validation.ValidationIssue issue,
) => switch (issue.kind) {
  native_validation.ValidationIssueKind_Error(:final field0) => _localizeValidationError(
    context,
    ref,
    field0,
  ),
  native_validation.ValidationIssueKind_Warning(:final field0) => _localizeValidationWarning(
    context,
    field0,
  ),
};

_FitIssue _localizeValidationError(
  BuildContext context,
  WidgetRef ref,
  native_validation.ValidationErrorKey key,
) => switch (key) {
  native_validation.ValidationErrorKey_IncompatibleChargeSize(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueIncompatibleChargeSize,
      details: context.l10n.fitIssueIncompatibleChargeSizeDetails(
        expected: _sizeName(context, expected),
        actual: _sizeName(context, actual),
      ),
    ),
  native_validation.ValidationErrorKey_IncompatibleChargeCapacity(:final max, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueIncompatibleChargeCapacity,
      details: context.l10n.fitIssueIncompatibleChargeCapacityDetails(
        max: max.toStringAsMaxDecimals(1),
        actual: actual.toStringAsMaxDecimals(1),
      ),
    ),
  native_validation.ValidationErrorKey_IncompatibleChargeGroup(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueIncompatibleChargeGroup,
      details: context.l10n.fitIssueIncompatibleChargeGroupDetails(
        expected: expected.map((groupId) => _localizedGroupName(ref, groupId)).join(", "),
        actual: _localizedGroupName(ref, actual),
      ),
    ),
  native_validation.ValidationErrorKey_TooMuchTurret(:final expected, :final actual) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueTooMuchTurret,
    details: context.l10n.fitIssueTooMuchTurretDetails(expected: expected, actual: actual),
  ),
  native_validation.ValidationErrorKey_TooMuchLauncher(:final expected, :final actual) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueTooMuchLauncher,
    details: context.l10n.fitIssueTooMuchLauncherDetails(expected: expected, actual: actual),
  ),
  native_validation.ValidationErrorKey_ConflictItem(:final groupId) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueConflictItem,
    details: context.l10n.fitIssueConflictItemDetails(groupName: _localizedGroupName(ref, groupId)),
  ),
  native_validation.ValidationErrorKey_DuplicateBooster(:final slot) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueDuplicateBooster,
    details: context.l10n.fitIssueDuplicateBoosterDetails(slot: slot),
  ),
  native_validation.ValidationErrorKey_IncompatibleShipGroup(:final expected) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueIncompatibleShipGroup,
    details: context.l10n.fitIssueIncompatibleShipGroupDetails(
      expected: expected.map((groupId) => _localizedGroupName(ref, groupId)).join(", "),
    ),
  ),
  native_validation.ValidationErrorKey_IncompatibleShipType(:final expected) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueIncompatibleShipType,
    details: context.l10n.fitIssueIncompatibleShipTypeDetails(
      expected: expected.map((typeId) => _localizedTypeName(ref, typeId)).join(", "),
    ),
  ),
  native_validation.ValidationErrorKey_IncompatibleRigSize(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueIncompatibleRigSize,
      details: context.l10n.fitIssueIncompatibleRigSizeDetails(
        expected: _sizeName(context, expected),
        actual: _sizeName(context, actual),
      ),
    ),
  native_validation.ValidationErrorKey_PowergridExceeded(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssuePowergridExceeded,
      details: context.l10n.fitIssuePowergridExceededDetails(
        expected: expected.toStringAsMaxDecimals(1),
        actual: actual.toStringAsMaxDecimals(1),
      ),
    ),
  native_validation.ValidationErrorKey_CpuExceeded(:final expected, :final actual) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueCpuExceeded,
    details: context.l10n.fitIssueCpuExceededDetails(
      expected: expected.toStringAsMaxDecimals(1),
      actual: actual.toStringAsMaxDecimals(1),
    ),
  ),
  native_validation.ValidationErrorKey_CalibrationExceeded(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueCalibrationExceeded,
      details: context.l10n.fitIssueCalibrationExceededDetails(
        expected: expected.toStringAsMaxDecimals(1),
        actual: actual.toStringAsMaxDecimals(1),
      ),
    ),
  native_validation.ValidationErrorKey_DroneBandwidthExceeded(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueDroneBandwidthExceeded,
      details: context.l10n.fitIssueDroneBandwidthExceededDetails(
        expected: expected.toStringAsMaxDecimals(1),
        actual: actual.toStringAsMaxDecimals(1),
      ),
    ),
  native_validation.ValidationErrorKey_DroneBayExceeded(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueDroneBayExceeded,
      details: context.l10n.fitIssueDroneBayExceededDetails(
        expected: expected.toStringAsMaxDecimals(1),
        actual: actual.toStringAsMaxDecimals(1),
      ),
    ),
  native_validation.ValidationErrorKey_TooManyActiveDrones(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueTooManyActiveDrones,
      details: context.l10n.fitIssueTooManyActiveDronesDetails(expected: expected, actual: actual),
    ),
  native_validation.ValidationErrorKey_TooMuchFighterTube(:final expected, :final actual) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueTooMuchFighterTube,
      details: context.l10n.fitIssueTooMuchFighterTubeDetails(expected: expected, actual: actual),
    ),
  native_validation.ValidationErrorKey_TooMuchFighterSquadron(
    :final category,
    :final expected,
    :final actual,
  ) =>
    _FitIssue(
      severity: _FitIssueSeverity.error,
      title: context.l10n.fitIssueTooMuchFighterSquadron(
        category: _fighterSquadronName(context, category),
      ),
      details: context.l10n.fitIssueTooMuchFighterSquadronDetails(
        expected: expected,
        actual: actual,
      ),
    ),
  native_validation.ValidationErrorKey_StateExceedsMax(:final state, :final maxState) => _FitIssue(
    severity: _FitIssueSeverity.error,
    title: context.l10n.fitIssueStateExceedsMax,
    details: context.l10n.fitIssueStateExceedsMaxDetails(
      state: _validationStateName(context, state),
      maxState: _validationStateName(context, maxState),
    ),
  ),
};

_FitIssue _localizeValidationWarning(
  BuildContext context,
  native_validation.ValidationWarningKey key,
) => switch (key) {
  native_validation.ValidationWarningKey.missingCharge => _FitIssue(
    severity: _FitIssueSeverity.warning,
    title: context.l10n.fitIssueMissingCharge,
    details: "",
  ),
};

native_validation.ValidationSlotType? _validationSlotTypeForSection(_FitIssueSection section) =>
    switch (section) {
      _FitIssueSection.tacticalMode => native_validation.ValidationSlotType.tacticalMode,
      _FitIssueSection.high => native_validation.ValidationSlotType.high,
      _FitIssueSection.medium => native_validation.ValidationSlotType.medium,
      _FitIssueSection.low => native_validation.ValidationSlotType.low,
      _FitIssueSection.rig => native_validation.ValidationSlotType.rig,
      _FitIssueSection.subsystem => native_validation.ValidationSlotType.subSystem,
      _FitIssueSection.service => native_validation.ValidationSlotType.service,
      _FitIssueSection.drone => native_validation.ValidationSlotType.drone,
      _FitIssueSection.fighter => native_validation.ValidationSlotType.fighter,
      _FitIssueSection.implant => native_validation.ValidationSlotType.implant,
      _FitIssueSection.booster => native_validation.ValidationSlotType.booster,
      _FitIssueSection.ship => native_validation.ValidationSlotType.ship,
    };

native_validation.ValidationSlotType? _validationSlotTypeForIdentifier(SlotIdentifier slotIdent) =>
    switch (slotIdent) {
      SlotIdentifierHigh() => native_validation.ValidationSlotType.high,
      SlotIdentifierMedium() => native_validation.ValidationSlotType.medium,
      SlotIdentifierLow() => native_validation.ValidationSlotType.low,
      SlotIdentifierRig() => native_validation.ValidationSlotType.rig,
      SlotIdentifierSubsystem() => native_validation.ValidationSlotType.subSystem,
      SlotIdentifierTacticalMode() => native_validation.ValidationSlotType.tacticalMode,
      SlotIdentifierService() => native_validation.ValidationSlotType.service,
      SlotIdentifierDrone() => native_validation.ValidationSlotType.drone,
      SlotIdentifierFighter() => native_validation.ValidationSlotType.fighter,
      SlotIdentifierImplant() => native_validation.ValidationSlotType.implant,
      SlotIdentifierBooster() => native_validation.ValidationSlotType.booster,
    };

String _localizedGroupName(WidgetRef ref, int groupId) {
  final group = ref.watch(repoCollectionProvider.select((c) => c?.getGroup(groupId)));
  if (group == null) return "$groupId";

  final locale = ref.watch(localeProvider).name;
  return watchLocalizedName(ref, id: group.groupName.id, locale: locale) ?? "$groupId";
}

String _localizedTypeName(WidgetRef ref, int typeId) {
  final type = ref.watch(repoCollectionProvider.select((c) => c?.getType(typeId)));
  if (type == null) return "$typeId";

  final locale = ref.watch(localeProvider).name;
  return watchLocalizedName(ref, id: type.typeName.id, locale: locale) ?? "$typeId";
}

String _sizeName(BuildContext context, int size) => switch (size) {
  1 => context.l10n.dogmaUnitSizeSmall,
  2 => context.l10n.dogmaUnitSizeMedium,
  3 => context.l10n.dogmaUnitSizeLarge,
  4 => context.l10n.dogmaUnitSizeXLarge,
  _ => context.l10n.dogmaUnitSizeUnknown(value: "$size"),
};

String _validationStateName(BuildContext context, native_validation.ValidationState state) =>
    switch (state) {
      native_validation.ValidationState.passive => context.l10n.itemDetailEffectCategoryPassive,
      native_validation.ValidationState.online => context.l10n.itemDetailEffectCategoryOnline,
      native_validation.ValidationState.active => context.l10n.itemDetailEffectCategoryActive,
      native_validation.ValidationState.overload => context.l10n.itemDetailEffectCategoryOverload,
    };

String _fighterSquadronName(BuildContext context, native_validation.FighterSquadron category) =>
    switch (category) {
      native_validation.FighterSquadron.light => context.l10n.fitIssueFighterSquadronLight,
      native_validation.FighterSquadron.support => context.l10n.fitIssueFighterSquadronSupport,
      native_validation.FighterSquadron.heavy => context.l10n.fitIssueFighterSquadronHeavy,
    };

class _FitIssueTrigger extends StatelessWidget {
  const _FitIssueTrigger({required this.issues, this.interactive = true});

  final List<_FitIssue> issues;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final hasError = issues.any((issue) => issue.severity == _FitIssueSeverity.error);

    return WarningTrigger(
      type: hasError ? WarningType.error : WarningType.warning,
      onTap: interactive
          ? () => showDialog<void>(
              context: context,
              builder: (context) => AppDialog(
                title: context.l10n.fitIssueDialogTitle,
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: issues
                        .map(
                          (issue) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              issue.severity == _FitIssueSeverity.error
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                            ),
                            title: Text(issue.title),
                            subtitle: issue.details.isEmpty ? null : Text(issue.details),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
