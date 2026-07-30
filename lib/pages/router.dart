import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/repository/manual_feedback_api.dart";
import "package:eve_fit_assistant/pages/announcements/feed_page.dart";
import "package:eve_fit_assistant/pages/fit/page.dart";
import "package:eve_fit_assistant/pages/manual/browser_page.dart";
import "package:eve_fit_assistant/pages/manual/feedback_page.dart";
import "package:eve_fit_assistant/pages/manual/node_page.dart";
import "package:eve_fit_assistant/pages/report/external_links_page.dart";
import "package:eve_fit_assistant/pages/report/page.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/collect_logs_page.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/page.dart";
import "package:eve_fit_assistant/pages/setting/app-settings/remote_content.dart";
import "package:eve_fit_assistant/pages/setting/channel_overview/page.dart";
import "package:eve_fit_assistant/pages/setting/data/channel_metadata.dart";
import "package:eve_fit_assistant/pages/setting/data/checkout_history.dart";
import "package:eve_fit_assistant/pages/setting/data/checkout_management.dart";
import "package:eve_fit_assistant/pages/setting/data/storage.dart";
import "package:eve_fit_assistant/pages/setting/developer-tools/page.dart";
import "package:eve_fit_assistant/pages/setting/developer/page.dart";
import "package:eve_fit_assistant/pages/setting/version/page.dart";
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
    AutoRoute(path: "/setting/remote-content", page: RemoteContentSettingsRoute.page),
    AutoRoute(path: "/setting/collect-logs", page: CollectLogsRoute.page),
    AutoRoute(path: "/setting/data/storage", page: StorageManagement.page),
    AutoRoute(path: "/setting/data/channel-metadata", page: ChannelMetadataRoute.page),
    AutoRoute(path: "/setting/data/checkouts", page: CheckoutManagementRoute.page),
    AutoRoute(path: "/setting/data/checkout-history", page: CheckoutHistoryRoute.page),
    AutoRoute(path: "/setting/developer-tools", page: DeveloperToolsRoute.page),
    AutoRoute(path: "/setting/developer-settings", page: DeveloperSettingsRoute.page),
    AutoRoute(path: "/setting/channel-overview", page: ChannelOverviewRoute.page),
    AutoRoute(path: "/setting/version", page: VersionRoute.page),
    AutoRoute(path: "/setting/report-feedback", page: ReportFeedbackRoute.page),
    AutoRoute(path: "/setting/report-feedback/external", page: ReportExternalLinksRoute.page),
    AutoRoute(path: "/announcements", page: AnnouncementFeedRoute.page),
    AutoRoute(path: "/manual", page: ManualBrowserRoute.page),
    AutoRoute(path: "/manual/feedback", page: ManualFeedbackRoute.page),
    AutoRoute(path: "/manual/*", page: ManualNodeRoute.page, usesPathAsKey: true),
    AutoRoute(path: "/fitting/current", page: FitRoute.page),
  ];
}

extension RouterExtensions on StackRouter {
  Future<void> popToRootAndPush(PageRouteInfo route) => replaceAll([const FrontRoute(), route]);
  Future<void> popToRootAndPushAll(List<PageRouteInfo> routes) =>
      replaceAll([const FrontRoute(), ...routes]);
}
