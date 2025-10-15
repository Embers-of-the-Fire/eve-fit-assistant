import 'package:auto_route/auto_route.dart';
import 'package:eve_fit_assistant/pages/setting/app-settings/page.dart';
import 'package:eve_fit_assistant/pages/view.dart';

part 'router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  final List<AutoRoute> routes = [
    AutoRoute(path: "/", page: FrontRoute.page),
    AutoRoute(path: "/setting/app-settings", page: AppSettingsRoute.page),
  ];
}
