import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/deeplink/deeplink_meta.dart";
import "package:eve_fit_assistant/features/manual/repository/manual_feedback_api.dart";
import "package:eve_fit_assistant/pages/ai/page.dart";
import "package:eve_fit_assistant/pages/ai/settings_page.dart";
import "package:eve_fit_assistant/pages/announcements/feed_page.dart";
import "package:eve_fit_assistant/pages/chat/chat_history_page.dart";
import "package:eve_fit_assistant/pages/chat/chat_page.dart";
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
    AutoRoute(
      path: "/",
      page: FrontRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "Workspace",
          usage: "the main workspace listing the user's fits",
        ),
      },
    ),
    AutoRoute(
      path: "/workspace/create-fit",
      page: FitCreationRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(title: "Create fit", usage: "create a new fit for a ship"),
      },
    ),
    AutoRoute(
      path: "/setting/app-settings",
      page: AppSettingsRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "App settings",
          usage: "application preferences such as language and appearance",
        ),
      },
    ),
    AutoRoute(
      path: "/ai",
      page: AiRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "AI assistant",
          usage: "the AI assistant hub: chat, history and configuration",
        ),
      },
    ),
    AutoRoute(
      path: "/ai/settings",
      page: AiChatSettingsRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "AI chat settings",
          usage: "configure the AI provider: base URL, model and API key",
        ),
      },
    ),
    AutoRoute(path: "/setting/remote-content", page: RemoteContentSettingsRoute.page),
    AutoRoute(path: "/setting/collect-logs", page: CollectLogsRoute.page),
    AutoRoute(
      path: "/setting/data/storage",
      page: StorageManagement.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "Storage management",
          usage: "manage downloaded data snapshots, checkouts and integrity verification",
        ),
      },
    ),
    AutoRoute(path: "/setting/data/channel-metadata", page: ChannelMetadataRoute.page),
    AutoRoute(path: "/setting/data/checkouts", page: CheckoutManagementRoute.page),
    AutoRoute(path: "/setting/data/checkout-history", page: CheckoutHistoryRoute.page),
    AutoRoute(path: "/setting/developer-tools", page: DeveloperToolsRoute.page),
    AutoRoute(path: "/setting/developer-settings", page: DeveloperSettingsRoute.page),
    AutoRoute(path: "/setting/channel-overview", page: ChannelOverviewRoute.page),
    AutoRoute(
      path: "/setting/version",
      page: VersionRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "Version info",
          usage: "app version and update information",
        ),
      },
    ),
    AutoRoute(path: "/setting/report-feedback", page: ReportFeedbackRoute.page),
    AutoRoute(path: "/setting/report-feedback/external", page: ReportExternalLinksRoute.page),
    AutoRoute(path: "/announcements", page: AnnouncementFeedRoute.page),
    AutoRoute(
      path: "/manual",
      page: ManualBrowserRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(title: "Manual", usage: "the in-app user manual home"),
      },
    ),
    AutoRoute(path: "/manual/feedback", page: ManualFeedbackRoute.page),
    AutoRoute(
      path: "/manual/*",
      page: ManualNodeRoute.page,
      usesPathAsKey: true,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "Manual topic",
          usage: "a specific manual page; link to efa://manual/<topic-path> for the topic",
        ),
      },
    ),
    AutoRoute(path: "/fitting/current", page: FitRoute.page),
    AutoRoute(
      path: "/chat",
      page: ChatRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "AI chat",
          usage: "start or continue an AI assistant conversation",
        ),
      },
    ),
    AutoRoute(
      path: "/chat/history",
      page: ChatHistoryRoute.page,
      meta: const {
        DeepLinkMeta.key: DeepLinkMeta(
          title: "Chat history",
          usage: "browse previous AI assistant conversations",
        ),
      },
    ),
  ];
}

extension RouterExtensions on StackRouter {
  Future<void> popToRootAndPush(PageRouteInfo route) => replaceAll([const FrontRoute(), route]);
  Future<void> popToRootAndPushAll(List<PageRouteInfo> routes) =>
      replaceAll([const FrontRoute(), ...routes]);
}
