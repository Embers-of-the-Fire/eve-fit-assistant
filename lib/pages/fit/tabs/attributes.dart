part of "../page.dart";

class _AttributeTab extends ConsumerWidget {
  const _AttributeTab({required this.fit});

  final FitStorage fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Center(
    child: Container(
      padding: const EdgeInsets.all(12),
      child: Text("${ref.watch(nativeEmulatedShipProvider(fit.metadata.fitId))}"),
    ),
  );
}
