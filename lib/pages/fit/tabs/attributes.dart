part of "../page.dart";

class _AttributeTab extends ConsumerStatefulWidget {
  const _AttributeTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

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
            ShipInfo(fitContext: widget.fitContext, interactionOptions: widget.interactionOptions),
            const Divider(height: 0),
            Capacitor(ship: emulated),
            Weapon(ship: emulated),
            _Resource(
              ship: emulated,
              issues: _collectFitIssuesForSection(
                context,
                ref,
                widget.fitContext,
                _FitIssueSection.ship,
              ),
            ),
            Hp(
              ship: emulated,
              fitId: widget.fitContext.fitId,
              interactionOptions: widget.interactionOptions,
            ),
            Miscellaneous(ship: emulated),
            Cargo(ship: emulated),
            // Market price lookups are not available on web; hide the tile so
            // the price provider chain is never triggered there.
            if (!kIsWeb) FitPriceTile(fitId: widget.fitContext.fitId),
          ],
        ),
      ),
    );
  }
}
