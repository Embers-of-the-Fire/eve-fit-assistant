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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
    child: Row(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: leftActions,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (issues.isNotEmpty) ...[
                  _FitIssueTrigger(issues: issues),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: rightInfo,
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
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        minVerticalPadding: 0,
        minTileHeight: 0,
        contentPadding: const .only(top: 10, left: 16, right: 16, bottom: 4),
        title: Text(title),
        trailing: rightInfo.isEmpty && issues.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 12,
                children: [
                  ...rightInfo,
                  if (issues.isNotEmpty)
                    _FitIssueTrigger(issues: issues, interactive: interactiveIssueIndicator),
                ],
              ),
      ),
      if (actions?.isNotEmpty ?? false) ...[
        const Divider(height: 8),
        Padding(
          padding: const .only(left: 16, right: 16, bottom: 2),
          child: Row(spacing: 10, children: actions!),
        ),
      ],
      const Divider(height: 4),
    ],
  );
}

class _HeaderCapacityCounter extends StatelessWidget {
  const _HeaderCapacityCounter({
    required this.count,
    required this.total,
    this.prefix,
    this.suffix,
  });

  final String? prefix;
  final String? suffix;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = count > total ? Colors.red : null;
    final textStyle = DefaultTextStyle.of(context).style;

    return Text.rich(
      TextSpan(
        children: [
          if (prefix != null) TextSpan(text: "$prefix "),
          TextSpan(
            text: "$count",
            style: textStyle.copyWith(color: color),
          ),
          TextSpan(text: " / $total"),
          if (suffix != null) TextSpan(text: " $suffix"),
        ],
      ),
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }
}

class _EquipmentHeaderCounter extends StatelessWidget {
  const _EquipmentHeaderCounter({required this.icon, required this.count, required this.total});

  final ImageProvider icon;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = count > total ? Colors.red : null;
    final textStyle = DefaultTextStyle.of(context).style;

    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Image(image: icon, height: 16),
          ),
          TextSpan(
            text: " $count",
            style: textStyle.copyWith(color: color),
          ),
          TextSpan(text: " / $total"),
        ],
      ),
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }
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
          _EquipmentHeaderCounter(
            icon: ImageAssets.weaponTurretNum,
            count: usedTurret,
            total: totalTurret,
          ),
        if (totalLauncher > 0 || usedLauncher > 0)
          _EquipmentHeaderCounter(
            icon: ImageAssets.weaponLauncherNum,
            count: usedLauncher,
            total: totalLauncher,
          ),
      ],
    );
  }
}
