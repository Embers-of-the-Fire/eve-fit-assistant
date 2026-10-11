import "dart:async";
import "dart:math" as math;

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/model_asset.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_scene/scene.dart";
import "package:vector_math/vector_math.dart" as vm;

/// Textures are decoded down to this longest-side cap at import time, so a
/// 4K ship never holds its full-size pixels in memory on a phone.
const int kShipModelMaxTextureSize = 2048;

/// The viewer pixel ratio is capped so high-DPI phones don't rasterize the 3D
/// scene at full device resolution.
const double kShipModelMaxPixelRatio = 2;

/// Vertical field of view of the viewer camera.
const double _kFovY = 45 * math.pi / 180;

/// Auto-rotation speed in radians per second (applied while idle).
const double _kAutoRotateSpeed = 0.25;

enum _ShipModelStatus { loading, ready, unavailable, error }

/// An interactive 3D view of a ship's baked model (flutter_scene / Flutter
/// GPU), fed from the lazy `static/models/ships/<typeId>.<variant>.glb`
/// blobs.
///
/// The variant defaults to the `shipModelVariant` app setting; the overlay
/// toggle switches variants for this view only, without writing the setting.
/// When the type has no model (or the load fails), [fallback] is rendered
/// instead.
///
/// The widget fills its parent; give it bounded constraints.
class ShipModelViewer extends ConsumerStatefulWidget {
  const ShipModelViewer({required this.typeId, this.fallback, super.key});

  final int typeId;

  /// Rendered when no model is available for [typeId] or loading fails.
  final Widget? fallback;

  @override
  ConsumerState<ShipModelViewer> createState() => ShipModelViewerState();
}

class ShipModelViewerState extends ConsumerState<ShipModelViewer> {
  Scene? _scene;
  _ShipModelStatus _status = _ShipModelStatus.loading;
  ShipModelVariant? _viewVariant;
  String? _loadingKey;

  // Orbit state: the camera looks at [_center] from [_distance] at the given
  // angles. Mutated by gestures and auto-rotate; the per-frame cameraBuilder
  // reads it, so no setState is needed for camera motion.
  final vm.Vector3 _center = vm.Vector3.zero();
  double _distance = 10;
  double _azimuth = 0;
  double _polar = 0.3;
  double _fovNear = 0.1;
  double _fovFar = 1000;
  bool _interacting = false;
  double _lastScale = 1;

  @override
  void dispose() {
    _scene?.dispose();
    super.dispose();
  }

  /// Restores the initial framing and variant default.
  void resetView() => setState(() {
    _azimuth = 0;
    _polar = 0.3;
    _distance = _framingDistance;
    _viewVariant = null;
  });

  /// Retries a failed load for the current type and variant. Clears the
  /// recorded load key so the next build starts exactly one new fetch; the
  /// failure paths keep [_loadingKey] set, so rebuilds alone never re-fetch.
  void retryLoad() {
    if (_status != _ShipModelStatus.error && _status != _ShipModelStatus.unavailable) return;
    setState(() {
      _loadingKey = null;
      _status = _ShipModelStatus.loading;
    });
  }

  double _framingDistance = 10;

  void _ensureLoading(ModelAssetService service, ShipModelVariant variant) {
    final key = "${widget.typeId}:${variant.token}";
    if (_loadingKey == key) return;
    _loadingKey = key;
    _status = _ShipModelStatus.loading;
    unawaited(_load(service, variant, key));
  }

  Future<void> _load(ModelAssetService service, ShipModelVariant variant, String key) async {
    try {
      final bytes = await service.readShipModel(widget.typeId, variant);
      if (!mounted || _loadingKey != key) return;
      if (bytes.isNone()) {
        setState(() => _status = _ShipModelStatus.unavailable);
        return;
      }
      await Scene.initializeStaticResources();
      final node = await Node.fromGlbBytes(
        bytes.toNullable()!,
        maxTextureSize: kShipModelMaxTextureSize,
        onWarning: (warning) => debug("ship model ${widget.typeId}: ${warning.message}"),
      );
      if (!mounted || _loadingKey != key) return;

      final scene = Scene();
      final bounds = node.combinedWorldBounds;
      if (bounds != null) {
        final c = (bounds.min + bounds.max) * 0.5;
        _center.setValues(c.x, c.y, c.z);
        final radius = math.max((bounds.max - bounds.min).length / 2, 1e-3);
        _framingDistance = radius / math.sin(_kFovY / 2);
        _distance = _framingDistance;
        _fovNear = math.max(radius / 1000, 0.01);
        _fovFar = _distance + radius * 4;
      }
      debug(
        "ship model ${widget.typeId} (${variant.token}): "
        "bounds=$bounds, distance=$_distance",
      );
      scene.add(node);

      final old = _scene;
      setState(() {
        _scene = scene;
        _status = _ShipModelStatus.ready;
      });
      old?.dispose();
    } catch (e) {
      debug("ship model ${widget.typeId} load failed: $e");
      if (mounted && _loadingKey == key) {
        setState(() => _status = _ShipModelStatus.error);
      }
    }
  }

  PerspectiveCamera _camera() {
    final offset = vm.Vector3(
      math.sin(_azimuth) * math.cos(_polar),
      math.sin(_polar),
      -math.cos(_azimuth) * math.cos(_polar),
    );
    return PerspectiveCamera(
      position: _center + offset * _distance,
      target: _center,
      fovNear: _fovNear,
      fovFar: _fovFar,
    );
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount <= 1) {
      _azimuth -= details.focalPointDelta.dx * 0.01;
      _polar = (_polar + details.focalPointDelta.dy * 0.01).clamp(-1.35, 1.35);
    } else {
      final factor = _lastScale == 0 ? 1.0 : details.scale / _lastScale;
      _distance = (_distance / factor).clamp(_framingDistance * 0.2, _framingDistance * 8);
    }
    _lastScale = details.scale;
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ?? const SizedBox.shrink();
    final serviceAsync = ref.watch(modelAssetServiceProvider);

    return serviceAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => fallback,
      data: (service) {
        if (service == null) return fallback;
        final ShipModelVariant preferred = _viewVariant ?? ref.watch(shipModelVariantProvider);
        var variant = preferred;
        if (!service.hasShipModel(widget.typeId, variant)) {
          final other = variant == ShipModelVariant.textured
              ? ShipModelVariant.geometryOnly
              : ShipModelVariant.textured;
          if (!service.hasShipModel(widget.typeId, other)) return fallback;
          variant = other;
        }
        _ensureLoading(service, variant);
        final scene = _scene;
        return switch (_status) {
          _ShipModelStatus.ready when scene != null => _buildViewer(context, scene, variant),
          _ShipModelStatus.unavailable || _ShipModelStatus.error => _buildFailed(context, fallback),
          _ => const Center(child: CircularProgressIndicator()),
        };
      },
    );
  }

  Widget _buildFailed(BuildContext context, Widget fallback) => Stack(
    fit: StackFit.expand,
    children: [
      fallback,
      Positioned(
        top: 4,
        right: 4,
        child: IconButton.filledTonal(
          visualDensity: VisualDensity.compact,
          tooltip: context.l10n.shipModelViewerRetry,
          icon: const Icon(Icons.refresh),
          onPressed: retryLoad,
        ),
      ),
    ],
  );

  Widget _buildViewer(BuildContext context, Scene scene, ShipModelVariant variant) {
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pixelRatio = math.min(MediaQuery.of(context).devicePixelRatio, kShipModelMaxPixelRatio);
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          onPointerDown: (_) => _interacting = true,
          onPointerUp: (_) => _interacting = false,
          onPointerCancel: (_) => _interacting = false,
          child: GestureDetector(
            onScaleStart: (_) => _lastScale = 1,
            onScaleUpdate: _onScaleUpdate,
            child: SceneView(
              scene,
              pixelRatio: pixelRatio,
              cameraBuilder: (_) => _camera(),
              onTick: reduceMotion
                  ? null
                  : (_, deltaSeconds) {
                      if (!_interacting) _azimuth += deltaSeconds * _kAutoRotateSpeed;
                    },
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            tooltip: variant == ShipModelVariant.textured
                ? l10n.shipModelViewerHideTextures
                : l10n.shipModelViewerShowTextures,
            icon: Icon(
              variant == ShipModelVariant.textured ? Icons.texture : Icons.texture_outlined,
            ),
            onPressed: () => setState(() {
              _viewVariant = variant == ShipModelVariant.textured
                  ? ShipModelVariant.geometryOnly
                  : ShipModelVariant.textured;
            }),
          ),
        ),
      ],
    );
  }
}
