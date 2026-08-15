import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/deeplink/link_surface.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The app's route collection, used to derive the link surface.
///
/// Must be overridden with the real router's collection in `main.dart`;
/// tests override it with a purpose-built collection.
final routeCollectionProvider = Provider<RouteCollection>(
  (Ref ref) => throw UnimplementedError(
    "routeCollectionProvider must be overridden with appRouter.routeCollection",
  ),
);

/// The linkable route surface exposed to the chat agent.
final linkSurfaceProvider = Provider<LinkSurface>(
  (Ref ref) => buildLinkSurface(ref.watch(routeCollectionProvider)),
);
