part of "../page.dart";

class _EquipmentTitleRow extends StatelessWidget {
  const _EquipmentTitleRow({
    this.leftActions = const <Widget>[],
    this.rightInfo = const <Widget>[],
  });

  final List<Widget> leftActions;
  final List<Widget> rightInfo;

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
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: rightInfo,
            ),
          ),
        ),
      ],
    ),
  );
}

class _EquipmentHeader extends StatelessWidget {
  const _EquipmentHeader({required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        minVerticalPadding: 0,
        minTileHeight: 0,
        contentPadding: const .only(top: 10, left: 16, right: 16, bottom: 4),
        title: Text(title),
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
