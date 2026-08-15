import "dart:ui" show lerpDouble;

import "package:flutter/material.dart";

/// Design tokens for the wizard component kit.
///
/// This is the single source of truth for the spacing scale, radii, paddings
/// and icon sizes shared by every wizard widget. Hosts attach it to their
/// [ThemeData.extensions]; widgets read it via [WizardTokens.of] so style
/// changes live here, not scattered as inline literals across the kit.
@immutable
class WizardTokens extends ThemeExtension<WizardTokens> {
  const WizardTokens({
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.spacingXxl,
    required this.cardRadius,
    required this.badgeRadius,
    required this.cardPadding,
    required this.badgePadding,
    required this.selectedIconSize,
    required this.statusIconSize,
    required this.contentVerticalPadding,
  });

  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double spacingXxl;
  final double cardRadius;
  final double badgeRadius;
  final EdgeInsets cardPadding;
  final EdgeInsets badgePadding;
  final double selectedIconSize;
  final double statusIconSize;
  final double contentVerticalPadding;

  /// The default token set used by the wizard kit when a host theme does not
  /// register its own [WizardTokens].
  static const WizardTokens standard = WizardTokens(
    spacingXs: 4,
    spacingSm: 8,
    spacingMd: 12,
    spacingLg: 16,
    spacingXl: 24,
    spacingXxl: 32,
    cardRadius: 12,
    badgeRadius: 8,
    cardPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    badgePadding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    selectedIconSize: 22,
    statusIconSize: 48,
    contentVerticalPadding: 32,
  );

  /// Reads the active [WizardTokens] from [context], falling back to
  /// [WizardTokens.standard] when no host theme registered them.
  static WizardTokens of(BuildContext context) =>
      Theme.of(context).extension<WizardTokens>() ?? standard;

  @override
  WizardTokens copyWith({
    double? spacingXs,
    double? spacingSm,
    double? spacingMd,
    double? spacingLg,
    double? spacingXl,
    double? spacingXxl,
    double? cardRadius,
    double? badgeRadius,
    EdgeInsets? cardPadding,
    EdgeInsets? badgePadding,
    double? selectedIconSize,
    double? statusIconSize,
    double? contentVerticalPadding,
  }) => WizardTokens(
    spacingXs: spacingXs ?? this.spacingXs,
    spacingSm: spacingSm ?? this.spacingSm,
    spacingMd: spacingMd ?? this.spacingMd,
    spacingLg: spacingLg ?? this.spacingLg,
    spacingXl: spacingXl ?? this.spacingXl,
    spacingXxl: spacingXxl ?? this.spacingXxl,
    cardRadius: cardRadius ?? this.cardRadius,
    badgeRadius: badgeRadius ?? this.badgeRadius,
    cardPadding: cardPadding ?? this.cardPadding,
    badgePadding: badgePadding ?? this.badgePadding,
    selectedIconSize: selectedIconSize ?? this.selectedIconSize,
    statusIconSize: statusIconSize ?? this.statusIconSize,
    contentVerticalPadding: contentVerticalPadding ?? this.contentVerticalPadding,
  );

  @override
  WizardTokens lerp(ThemeExtension<WizardTokens>? other, double t) {
    if (other is! WizardTokens) return this;
    return WizardTokens(
      spacingXs: lerpDouble(spacingXs, other.spacingXs, t)!,
      spacingSm: lerpDouble(spacingSm, other.spacingSm, t)!,
      spacingMd: lerpDouble(spacingMd, other.spacingMd, t)!,
      spacingLg: lerpDouble(spacingLg, other.spacingLg, t)!,
      spacingXl: lerpDouble(spacingXl, other.spacingXl, t)!,
      spacingXxl: lerpDouble(spacingXxl, other.spacingXxl, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      badgeRadius: lerpDouble(badgeRadius, other.badgeRadius, t)!,
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
      badgePadding: EdgeInsets.lerp(badgePadding, other.badgePadding, t)!,
      selectedIconSize: lerpDouble(selectedIconSize, other.selectedIconSize, t)!,
      statusIconSize: lerpDouble(statusIconSize, other.statusIconSize, t)!,
      contentVerticalPadding: lerpDouble(contentVerticalPadding, other.contentVerticalPadding, t)!,
    );
  }
}
