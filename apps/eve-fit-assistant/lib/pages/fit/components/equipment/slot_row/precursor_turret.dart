part of "../../../page.dart";

class _PrecursorTurretSpoolDpsLine extends StatelessWidget {
  const _PrecursorTurretSpoolDpsLine({required this.spool});

  final PrecursorTurretSpool spool;

  @override
  Widget build(BuildContext context) => _SlotRelatedValuesRow(
    segments: [
      (
        iconAttributeId: EveConstAttrID.damageMultiplier,
        text:
            "${spool.minDps.toStringAsMaxDecimals(1)} – "
            "${spool.maxDps.toStringAsMaxDecimals(1)} DPS",
      ),
    ],
  );
}
