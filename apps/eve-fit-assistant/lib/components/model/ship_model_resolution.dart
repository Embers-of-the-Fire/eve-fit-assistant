import "package:eve_fit_assistant/storage/repo/model_asset.dart";

/// How the variant actually being loaded relates to the preferred one.
enum ShipModelFallbackKind {
  /// The preferred variant was available and is used.
  none,

  /// The textured variant was preferred but is unavailable; the lightweight
  /// geometry-only variant is used instead. This is a quality downgrade and
  /// must be visible in the viewer.
  downgradedToGeometryOnly,

  /// The geometry-only variant was preferred but is unavailable; the textured
  /// variant is used instead. This is only a diagnostic curiosity, not a
  /// quality warning.
  upgradedToTextured,
}

/// The outcome of resolving which ship model variant to load for a type.
class ShipModelVariantResolution {
  const ShipModelVariantResolution._(this.variant, this.fallbackKind);

  /// The variant to load, or null when neither variant exists for the type.
  final ShipModelVariant? variant;

  /// The fallback relationship between [variant] and the preferred variant.
  final ShipModelFallbackKind fallbackKind;

  /// Whether the resolved [variant] differs from the preferred variant.
  bool get isFallback => variant != null && fallbackKind != ShipModelFallbackKind.none;

  /// Whether no variant exists for the type at all.
  bool get isUnavailable => variant == null;
}

/// Resolves which [ShipModelVariant] to load for a ship.
///
/// The [preferred] variant comes from the `shipModelVariant` setting or a
/// per-view explicit selection. When it is missing from the active checkout,
/// the other variant is used as an explicit, recorded fallback instead of
/// silently substituting it.
ShipModelVariantResolution resolveShipModelVariant({
  required ShipModelVariant preferred,
  required bool Function(ShipModelVariant variant) hasVariant,
}) {
  if (hasVariant(preferred)) {
    return ShipModelVariantResolution._(preferred, ShipModelFallbackKind.none);
  }
  final fallback = preferred == ShipModelVariant.textured
      ? ShipModelVariant.geometryOnly
      : ShipModelVariant.textured;
  if (!hasVariant(fallback)) {
    return const ShipModelVariantResolution._(null, ShipModelFallbackKind.none);
  }
  return ShipModelVariantResolution._(
    fallback,
    preferred == ShipModelVariant.textured
        ? ShipModelFallbackKind.downgradedToGeometryOnly
        : ShipModelFallbackKind.upgradedToTextured,
  );
}
