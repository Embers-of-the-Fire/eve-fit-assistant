import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/src/context.dart";
import "package:efa_fit_snapshot/src/l10n.dart";
import "package:efa_fit_snapshot/src/widgets/character_column.dart";
import "package:efa_fit_snapshot/src/widgets/equipment_column.dart";
import "package:efa_fit_snapshot/src/widgets/statistics_column.dart";
import "package:flutter/material.dart";

/// Read-only, localization-aware display of a [FitSnapshot].
///
/// Renders the character, equipment and attributes columns purely from the
/// snapshot protobuf — no localization database, image registry or fitting
/// engine required. Type icons resolve through an optional [EfaIconResolver]
/// and fall back to the bundled placeholder.
class FitSnapshotView extends StatelessWidget {
  const FitSnapshotView({
    required this.snapshot,
    super.key,
    this.locale,
    this.iconResolver,
    this.showHeader = true,
  });

  static const double _columnWidth = 420;

  final FitSnapshot snapshot;
  final Locale? locale;
  final EfaIconResolver? iconResolver;

  /// Whether to show the fit name/description header above the columns.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final effectiveLocale = locale ?? Localizations.maybeLocaleOf(context) ?? const Locale("en");

    return Localizations(
      locale: effectiveLocale,
      delegates: const [
        SnapshotLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: SnapshotDisplay(
        resolver: iconResolver,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columnCount = width >= _columnWidth * 3 + 48
                ? 3
                : width >= _columnWidth * 2 + 36
                ? 2
                : 1;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showHeader) _SnapshotHeader(snapshot: snapshot),
                  switch (columnCount) {
                    3 => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        _column(SnapshotCharacterColumn(snapshot: snapshot)),
                        _column(SnapshotEquipmentColumn(snapshot: snapshot)),
                        _column(SnapshotStatisticsColumn(snapshot: snapshot)),
                      ],
                    ),
                    2 => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: [
                        _column(SnapshotEquipmentColumn(snapshot: snapshot)),
                        _column(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SnapshotCharacterColumn(snapshot: snapshot),
                              const SizedBox(height: 12),
                              SnapshotStatisticsColumn(snapshot: snapshot),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _ => Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 12,
                      children: [
                        SnapshotEquipmentColumn(snapshot: snapshot),
                        SnapshotCharacterColumn(snapshot: snapshot),
                        SnapshotStatisticsColumn(snapshot: snapshot),
                      ],
                    ),
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _column(Widget child) => Expanded(child: _SnapshotColumnFrame(child: child));
}

class _SnapshotColumnFrame extends StatelessWidget {
  const _SnapshotColumnFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    foregroundDecoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: child),
    ),
  );
}

class _SnapshotHeader extends StatelessWidget {
  const _SnapshotHeader({required this.snapshot});

  final FitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final header = snapshot.header;
    final shipName = resolveSnapshotName(snapshot.ship.type.names, locale);
    return ListTile(
      title: Text(context.snapshotL10n.fitPageTitle(fitName: header.fitName, shipName: shipName)),
      subtitle: header.hasDescription() && header.description.isNotEmpty
          ? Text(header.description)
          : null,
    );
  }
}
