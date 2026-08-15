import "package:flutter/material.dart";

/// A rack/section title row with an optional action strip, mirroring the app's
/// equipment headers without the mutation-side issue reporting.
class EfaSectionHeader extends StatelessWidget {
  const EfaSectionHeader({required this.title, super.key, this.actions, this.trailing = const []});

  final String title;
  final List<Widget>? actions;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        minVerticalPadding: 0,
        minTileHeight: 0,
        contentPadding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
        title: Text(title),
        trailing: trailing.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, spacing: 12, children: trailing),
      ),
      if (actions?.isNotEmpty ?? false) ...[
        const Divider(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 2),
          child: Row(spacing: 10, children: actions!),
        ),
      ],
      const Divider(height: 4),
    ],
  );
}

/// A title row with left actions and right-aligned info widgets.
class EfaTitleRow extends StatelessWidget {
  const EfaTitleRow({super.key, this.leftActions = const [], this.rightInfo = const []});

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

/// A `count / total` counter with optional prefix/suffix; red when over.
class CapacityCounter extends StatelessWidget {
  const CapacityCounter({
    required this.count,
    required this.total,
    super.key,
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

/// A `count / total` counter led by a small icon; red when over.
class HeaderIconCounter extends StatelessWidget {
  const HeaderIconCounter({
    required this.icon,
    required this.count,
    required this.total,
    super.key,
  });

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
