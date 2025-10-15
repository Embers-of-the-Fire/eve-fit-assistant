import 'package:eve_fit_assistant/utils/fp.dart';
import 'package:flutter/material.dart';

class ConfigListView extends StatelessWidget {
  final List<ConfigListTile> children;
  const ConfigListView({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];
    if (this.children.firstOrNull is _ConfigListTileItem) {
      children.add(_divider);
    }
    for (final (curr, next) in this.children.window2()) {
      children.add(curr);
      if ((curr is _ConfigListTileSpace &&
              (next is _ConfigListTileItem || next is _ConfigListTileCustom)) ||
          curr is _ConfigListTileItem ||
          curr is _ConfigListTileCustom ||
          curr is _ConfigListTileTitle) {
        children.add(_divider);
      }
    }
    return ListView(padding: EdgeInsets.only(right: 10), children: children);
  }
}

const _divider = Divider(indent: 0, endIndent: 0, height: 0, thickness: 0.5);

sealed class ConfigListTile extends StatelessWidget {
  const factory ConfigListTile.space(num height) = _ConfigListTileSpace;

  const factory ConfigListTile.title(String title) = _ConfigListTileTitle;

  const factory ConfigListTile.item({
    IconData? icon,
    required String title,
    String? subtitle,
    void Function()? onTap,
  }) = _ConfigListTileItem;

  const factory ConfigListTile.custom(Widget child) = _ConfigListTileCustom;

  const ConfigListTile._();
}

class _ConfigListTileSpace extends ConfigListTile {
  final num height;
  const _ConfigListTileSpace([this.height = 10]) : super._();

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height.toDouble());
  }
}

class _ConfigListTileTitle extends ConfigListTile {
  final String title;
  const _ConfigListTileTitle(this.title) : super._();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 24, bottom: 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _ConfigListTileItem extends ConfigListTile {
  final IconData? icon;
  final String title;
  final String? subtitle;

  final void Function()? onTap;

  const _ConfigListTileItem({this.icon, required this.title, this.subtitle, this.onTap})
    : super._();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: ListTile(
        leading: icon != null ? Icon(icon) : const SizedBox.shrink(),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: onTap.optional.map((_) => const Icon(Icons.chevron_right)).nullable,
        onTap: onTap,
      ),
    );
  }
}

class _ConfigListTileCustom extends ConfigListTile {
  final Widget child;
  const _ConfigListTileCustom(this.child) : super._();

  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).colorScheme.surfaceContainer, child: child);
  }
}
