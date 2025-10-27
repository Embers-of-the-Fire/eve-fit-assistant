import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/page.dart";
import "package:eve_fit_assistant/pages/setting/bundle-manager/page.dart";
import "package:eve_fit_assistant/pages/view.dart";
import "package:eve_fit_assistant/pages/workspace/create-fit/page.dart";
import "package:flutter/material.dart";

part "router.gr.dart";

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  final List<AutoRoute> routes = [
    AutoRoute(path: "/", page: FrontRoute.page),
    AutoRoute(path: "/workspace/create-fit", page: FitCreationRoute.page),
    AutoRoute(path: "/setting/app-settings", page: AppSettingsRoute.page),
    AutoRoute(path: "/setting/bundle-manager", page: BundleManagerRoute.page),
    AutoRoute(path: "/setting/bundle-manager/:bundleId", page: BundleDetailRoute.page),
  ];
}
