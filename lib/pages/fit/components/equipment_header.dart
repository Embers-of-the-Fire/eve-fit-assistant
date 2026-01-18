part of "../page.dart";

class _EquipmentHeader extends StatelessWidget {
  const _EquipmentHeader({
    required this.title,
    this.actions,
    this.onErrorPrompted,
    this.trailing,
    this.warningType,
  });

  final String title;
  final Widget? trailing;
  final List<Widget>? actions;

  final WarningType? warningType;
  final void Function()? onErrorPrompted;

  @override
  Widget build(BuildContext context) {
    final errorTrigger = warningType != null
        ? WarningTrigger(type: warningType!, onTap: onErrorPrompted)
        : null;
    final trailing = this.trailing == null
        ? errorTrigger
        : Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              this.trailing!,
              if (errorTrigger != null) ...[const SizedBox(width: 8), errorTrigger],
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          minVerticalPadding: 0,
          minTileHeight: 0,
          contentPadding: const .only(top: 10, left: 16, right: 16, bottom: 4),
          title: Text(title),
          trailing: trailing,
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
}
