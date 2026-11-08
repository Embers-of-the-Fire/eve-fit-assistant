import "dart:math" as math;

import "package:efa_proto/skybox.pb.dart" as pb;
import "package:vector_math/vector_math.dart" as vm;

/// The EVE scene family a lighting profile describes.
enum AppLightingProfileKind { itemPreview, fitting }

/// How a profile aims its single directional key light.
enum AppSunDirectionMode { cameraForward, fixed }

/// A validated, fully resolved lighting profile used by the viewer.
///
/// This is deliberately separate from skybox metadata: a profile supplies
/// lighting semantics, while a skybox supplies environment assets. [sunColor]
/// is EVE's intensity/color product; the renderer uses [keyIntensity] with a
/// neutral-white light so that product is not applied twice.
class AppLightingProfile {
  const AppLightingProfile({
    required this.id,
    required this.kind,
    required this.skyboxId,
    required this.reflectionResource,
    required this.nebulaIntensity,
    required this.reflectionIntensity,
    required this.ambientColor,
    required this.sunColor,
    required this.sunDirectionMode,
    this.fixedSunDirection,
  });

  final String id;
  final AppLightingProfileKind kind;
  final String skyboxId;
  final String reflectionResource;
  final double nebulaIntensity;
  final double reflectionIntensity;
  final vm.Vector3 ambientColor;

  /// EVE's final key intensity/color product. Catalog profiles are neutral
  /// white, so all three components are equal.
  final vm.Vector3 sunColor;

  final AppSunDirectionMode sunDirectionMode;
  final vm.Vector3? fixedSunDirection;

  /// Scalar for a neutral-white `DirectionalLight`.
  double get keyIntensity => sunColor.x;

  /// Converts and validates one protobuf profile. Invalid profiles return
  /// `null`; selection then follows the documented generic/built-in fallback.
  static AppLightingProfile? tryFromProto(pb.SceneLightingProfile profile) {
    if (!profile.hasId() || profile.id.isEmpty) return null;
    if (!profile.hasKind() || !profile.hasSkyboxId() || profile.skyboxId.isEmpty) return null;
    if (!profile.hasReflectionResource() || profile.reflectionResource.isEmpty) return null;
    if (!profile.hasNebulaIntensity() ||
        !_finiteNonNegative(profile.nebulaIntensity) ||
        !profile.hasReflectionIntensity() ||
        !_finitePositive(profile.reflectionIntensity)) {
      return null;
    }
    if (!profile.hasAmbientColor() || !profile.hasSunColor()) return null;

    final ambient = _color(profile.ambientColor);
    final sun = _color(profile.sunColor);
    if (ambient == null || sun == null) return null;
    // All supported scenes have a neutral-white key. The proto stores the
    // intensity/color product, not an RGB color to multiply by intensity again.
    if (sun.x <= 0 || (sun.x - sun.y).abs() > 1e-6 || (sun.x - sun.z).abs() > 1e-6) {
      return null;
    }

    final AppLightingProfileKind kind;
    if (profile.kind == pb.LightingProfileKind.ITEM_PREVIEW) {
      kind = AppLightingProfileKind.itemPreview;
    } else if (profile.kind == pb.LightingProfileKind.FITTING) {
      kind = AppLightingProfileKind.fitting;
    } else {
      return null;
    }
    if (!profile.hasSunDirectionMode()) return null;

    final AppSunDirectionMode directionMode;
    vm.Vector3? fixedDirection;
    if (profile.sunDirectionMode == pb.SunDirectionMode.CAMERA_FORWARD) {
      directionMode = AppSunDirectionMode.cameraForward;
      if (kind != AppLightingProfileKind.itemPreview || profile.hasFixedSunDirection()) return null;
    } else if (profile.sunDirectionMode == pb.SunDirectionMode.FIXED) {
      directionMode = AppSunDirectionMode.fixed;
      if (kind != AppLightingProfileKind.fitting || !profile.hasFixedSunDirection()) return null;
      final direction = profile.fixedSunDirection;
      if (!direction.hasX() || !direction.hasY() || !direction.hasZ()) return null;
      if (!direction.x.isFinite || !direction.y.isFinite || !direction.z.isFinite) return null;
      final length = math.sqrt(
        direction.x * direction.x + direction.y * direction.y + direction.z * direction.z,
      );
      if (!length.isFinite || length <= 0) return null;
      fixedDirection = vm.Vector3(direction.x, direction.y, direction.z) / length;
    } else {
      return null;
    }

    return AppLightingProfile(
      id: profile.id,
      kind: kind,
      skyboxId: profile.skyboxId,
      reflectionResource: profile.reflectionResource,
      nebulaIntensity: profile.nebulaIntensity,
      reflectionIntensity: profile.reflectionIntensity,
      ambientColor: ambient,
      sunColor: sun,
      sunDirectionMode: directionMode,
      fixedSunDirection: fixedDirection,
    );
  }

  static vm.Vector3? _color(pb.RgbColor color) {
    if (!color.hasR() || !color.hasG() || !color.hasB()) return null;
    if (!_finiteNonNegative(color.r) ||
        !_finiteNonNegative(color.g) ||
        !_finiteNonNegative(color.b)) {
      return null;
    }
    return vm.Vector3(color.r, color.g, color.b);
  }

  static bool _finiteNonNegative(double value) => value.isFinite && value >= 0;

  static bool _finitePositive(double value) => value.isFinite && value > 0;
}

/// Minimal item-preview compatibility profile used when catalog data cannot
/// supply the requested profile.
final AppLightingProfile kGenericItemPreviewLightingProfile = AppLightingProfile(
  id: "generic",
  kind: AppLightingProfileKind.itemPreview,
  skyboxId: "m10",
  reflectionResource: "",
  nebulaIntensity: 1,
  reflectionIntensity: 1,
  ambientColor: vm.Vector3.all(0.25),
  sunColor: vm.Vector3.all(3),
  sunDirectionMode: AppSunDirectionMode.cameraForward,
);

/// Minimal fitting compatibility profile. The fixed direction is the authored
/// EVE travel direction with Z negated into app coordinates, then normalized.
final AppLightingProfile kFittingLightingProfile = AppLightingProfile(
  id: "fitting",
  kind: AppLightingProfileKind.fitting,
  skyboxId: "fitting",
  reflectionResource: "",
  nebulaIntensity: 1,
  reflectionIntensity: 1,
  ambientColor: vm.Vector3(0.30408299, 0.45882350, 0.45336211),
  sunColor: vm.Vector3.all(2),
  sunDirectionMode: AppSunDirectionMode.fixed,
  fixedSunDirection: vm.Vector3(-0.53916383, -0.53916383, 0.64699662).normalized(),
);
