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
    if (ref.watch(bundleCollectionGetTypeProvider(typeId)) != null) return;

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
    if (ref.watch(bundleCollectionGetTypeProvider(chargeTypeId)) != null) return;

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
        if (ref.watch(bundleCollectionGetTypeProvider(typeId)) != null) return;
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
  }

  return issues;
}

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
                            subtitle: Text(issue.details),
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
