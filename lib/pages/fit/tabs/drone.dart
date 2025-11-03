part of "../page.dart";

class _DroneTab extends StatelessWidget {
  const _DroneTab({required this.fit});

  final FitStorage fit;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(padding: const EdgeInsets.all(12), child: Text("${fit.body.drones}")),
  );
}
