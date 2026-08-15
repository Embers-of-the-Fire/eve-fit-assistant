part of "../page.dart";

class _ActionClearAll extends StatelessWidget {
  const _ActionClearAll({required this.onTap});

  final void Function() onTap;

  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: const Icon(Icons.clear_all));
}

class _ActionClearCharge extends StatelessWidget {
  const _ActionClearCharge({required this.onTap});

  final void Function() onTap;

  @override
  Widget build(BuildContext context) =>
      InkWell(onTap: onTap, child: const Icon(Icons.battery_alert_outlined));
}
