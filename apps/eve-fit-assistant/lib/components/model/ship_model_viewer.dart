import "dart:async";
import "dart:math" as math;

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
class ShipModelViewer extends ConsumerStatefulWidget {
  const ShipModelViewer({
    required this.typeId,
    this.aspectRatio = 16 / 10,
    this.fallback,
    super.key,
  });

  final int typeId;

  /// The width/height ratio of the viewer panel.
  final double aspectRatio;

  /// Rendered when no model is available for [typeId] or loading fails.
  final Widget? fallback;

  @override
  ConsumerState<ShipModelViewer> createState() => _ShipModelViewerState();
}

class _ShipModelViewerState extends ConsumerState<ShipModelViewer> {
  ({Scene scene, OrbitCameraController controller})? _bundle;
  _ShipModelStatus _status = _ShipModelStatus.loading;
  ShipModelVariant? _viewVariant;
  String? _loadingKey;
  bool _interacting = false;

  @override
  void dispose() {
    _bundle?.scene.dispose();
    super.dispose();
  }

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
        onWarning: (warning) => debugPrint("ship model ${widget.typeId}: ${warning.message}"),
      );
      if (!mounted || _loadingKey != key) return;

      final scene = Scene();
      var radius = 1.0;
      final bounds = node.combinedLocalBounds;
      if (bounds != null) {
        final center = (bounds.min + bounds.max) * 0.5;
        node.position = vm.Vector3(-center.x, -center.y, -center.z);
        radius = math.max((bounds.max - bounds.min).length / 2, 1e-3);
      }
      scene.add(node);

      final controller = OrbitCameraController(
        distance: radius * 2.6,
        minDistance: radius * 1.2,
        maxDistance: radius * 8,
      );
      final cameraNode = Node()
        ..addComponent(CameraComponent(activateOnMount: true))
        ..addComponent(controller);
      scene.add(cameraNode);

      final old = _bundle;
      setState(() {
        _bundle = (scene: scene, controller: controller);
        _status = _ShipModelStatus.ready;
      });
      old?.scene.dispose();
    } catch (e) {
      debugPrint("ship model ${widget.typeId} load failed: $e");
      if (mounted && _loadingKey == key) {
        setState(() => _status = _ShipModelStatus.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = widget.fallback ?? const SizedBox.shrink();
    final serviceAsync = ref.watch(modelAssetServiceProvider);

    return serviceAsync.when(
      loading: () => _panel(child: const Center(child: CircularProgressIndicator())),
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
        final bundle = _bundle;
        return switch (_status) {
          _ShipModelStatus.ready when bundle != null => _buildViewer(context, bundle, variant),
          _ShipModelStatus.unavailable || _ShipModelStatus.error => fallback,
          _ => _panel(child: const Center(child: CircularProgressIndicator())),
        };
      },
    );
  }

  Widget _panel({required Widget child}) =>
      AspectRatio(aspectRatio: widget.aspectRatio, child: child);

  Widget _buildViewer(
    BuildContext context,
    ({Scene scene, OrbitCameraController controller}) bundle,
    ShipModelVariant variant,
  ) {
    final l10n = context.l10n;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pixelRatio = math.min(MediaQuery.of(context).devicePixelRatio, kShipModelMaxPixelRatio);
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              onPointerDown: (_) => _interacting = true,
              onPointerUp: (_) => _interacting = false,
              onPointerCancel: (_) => _interacting = false,
              child: CameraControls(
                controller: bundle.controller,
                child: SceneView(
                  bundle.scene,
                  pixelRatio: pixelRatio,
                  onTick: reduceMotion
                      ? null
                      : (_, deltaSeconds) {
                          if (!_interacting) {
                            bundle.controller.orbitBy(deltaSeconds * _kAutoRotateSpeed, 0);
                          }
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
        ),
      ),
    );
  }
}
