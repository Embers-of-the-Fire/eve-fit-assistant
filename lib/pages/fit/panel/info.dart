part of 'fit.dart';

class InfoTab extends ConsumerStatefulWidget {
  final String fitID;

  const InfoTab({super.key, required this.fitID});

  @override
  ConsumerState<InfoTab> createState() => _InfoTabState();
}

class _InfoTabState extends ConsumerState<InfoTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final fitRef = ref.watch(fitRecordNotifierProvider(widget.fitID));
    final out = fitRef.output.ship;
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ShipInfo(fitID: widget.fitID),
            const Divider(height: 0),
            Capacitor(ship: out),
            Weapon(ship: out),
            Resource(ship: out),
            Hp(fitID: widget.fitID, ship: out),
            Extra(ship: out),
            Cargo(ship: out),
            MarketPriceInfo(fitID: widget.fitID),
          ],
        ),
      ),
    );
  }
}
