part of "../page.dart";

class _EquipmentTitleRow extends StatelessWidget {
  const _EquipmentTitleRow({
    this.leftActions = const <Widget>[],
    this.rightInfo = const <Widget>[],
    this.issues = const <_FitIssue>[],
  });

  final List<Widget> leftActions;
  final List<Widget> rightInfo;
  final List<_FitIssue> issues;

  @override
  Widget build(BuildContext context) => EfaTitleRow(
    leftActions: leftActions,
    rightInfo: [
      ...rightInfo,
      if (issues.isNotEmpty) _FitIssueTrigger(issues: issues),
    ],
  );
}

class _EquipmentHeader extends StatelessWidget {
  const _EquipmentHeader({
    required this.title,
    this.actions,
    this.rightInfo = const <Widget>[],
    this.issues = const <_FitIssue>[],
    this.interactiveIssueIndicator = true,
  });

  final String title;
  final List<Widget>? actions;
  final List<Widget> rightInfo;
  final List<_FitIssue> issues;
  final bool interactiveIssueIndicator;

  @override
  Widget build(BuildContext context) => EfaSectionHeader(
    title: title,
    actions: actions,
    trailing: [
      ...rightInfo,
      if (issues.isNotEmpty)
        _FitIssueTrigger(issues: issues, interactive: interactiveIssueIndicator),
    ],
  );
}

class _HighSlotHardpointInfo extends ConsumerWidget {
  const _HighSlotHardpointInfo({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = ref.watch(repoCollectionProvider);
    if (collection == null) return const SizedBox.shrink();

    final fit = fitContext.fit;

    var usedTurret = 0;
    var usedLauncher = 0;
    for (final slot in fit.body.slots.high) {
      final item = slot.toNullable();
      if (item == null) continue;
      final typeId = fitContext.resolveOriginTypeId(item.itemId);
      if (typeId == null) continue;
      final info = collection.slots.highSlots[typeId];
      if (info == null) continue;
      if (info.isTurret) usedTurret += 1;
      if (info.isLauncher) usedLauncher += 1;
    }

    var totalTurret = fitContext.ship.turretSlots;
    var totalLauncher = fitContext.ship.launcherSlots;
    for (final slot in fit.body.slots.subsystem) {
      final item = slot.toNullable();
      if (item == null) continue;
      final typeId = fitContext.resolveOriginTypeId(item.itemId);
      if (typeId == null) continue;
      final def = collection.getSubsystem(typeId);
      if (def == null) continue;
      totalTurret += def.turretSlots;
      totalLauncher += def.launcherSlots;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        if (totalTurret > 0 || usedTurret > 0)
          HeaderIconCounter(
            icon: ImageAssets.weaponTurretNum,
            count: usedTurret,
            total: totalTurret,
          ),
        if (totalLauncher > 0 || usedLauncher > 0)
          HeaderIconCounter(
            icon: ImageAssets.weaponLauncherNum,
            count: usedLauncher,
            total: totalLauncher,
          ),
      ],
    );
  }
}
