part of "../page.dart";

class _AttributeTab extends ConsumerStatefulWidget {
  const _AttributeTab({required this.fitContext});

  final FitContext fitContext;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _AttributeTabState();
}

class _AttributeTabState extends ConsumerState<_AttributeTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final emulated = widget.fitContext.emulated;
    if (emulated == null) {
      return const Center(
        child: SizedBox.square(
          dimension: 40,
          child: LoadingIndicator(indicatorType: Indicator.ballClipRotateMultiple),
        ),
      );
    }

    return Container(
      padding: const .only(bottom: 8),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ShipInfo(fitContext: widget.fitContext),
            const Divider(height: 0),
            Capacitor(ship: emulated),
            Weapon(ship: emulated),
            Resource(ship: emulated),
            Hp(ship: emulated),
            Miscellaneous(ship: emulated),
            Cargo(ship: emulated),
          ],
        ),
      ),
    );
  }
}
