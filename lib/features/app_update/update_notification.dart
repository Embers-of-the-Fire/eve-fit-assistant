import "dart:async";
import "dart:ui" as ui;

import "package:eve_fit_assistant/compat/io.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/app_update/format.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter/foundation.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "update_notification.g.dart";

/// Drives the Android system notification for background app-update
/// downloads: an ongoing progress notification while downloading, a
/// tap-to-install notification when the artifact is ready, and a failure
/// notification on errors.
///
/// All methods are no-ops off Android, so tests and desktop builds never
/// touch the plugin. Tap/action callbacks ([onInstallRequested],
/// [onCancelRequested]) are wired by the update gate/session layer.
abstract class UpdateNotificationService {
  /// Called when the user taps the ready-to-install notification (or its
  /// install action). The UI layer should surface an install confirmation.
  void Function()? onInstallRequested;

  /// Called when the user taps the cancel action on the progress
  /// notification. The session layer should cancel the active download.
  void Function()? onCancelRequested;

  Future<void> initialize();

  /// Requests the Android 13+ notification runtime permission. Returns
  /// whether notifications may be posted.
  Future<bool> ensurePermission();

  Future<void> showDownloadProgress({required int receivedBytes, required int totalBytes});

  Future<void> showReadyToInstall({required String version});

  Future<void> showFailed();

  Future<void> dismiss();
}

@riverpodSingleton
UpdateNotificationService updateNotificationService(Ref ref) => LocalUpdateNotificationService();

class LocalUpdateNotificationService implements UpdateNotificationService {
  static const int _notificationId = 4101;
  static const String _channelId = "app_updates";
  static const String _cancelActionId = "efa.app_update.cancel";
  static const String _installActionId = "efa.app_update.install";
  static const String _installPayload = "app_update.install";

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Future<void>? _initializing;

  @override
  void Function()? onInstallRequested;

  @override
  void Function()? onCancelRequested;

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  AppLocalizations get _l10n =>
      lookupAppLocalizations(ui.Locale(AppSettingService.appSetting.locale.name));

  @override
  Future<void> initialize() {
    if (!_supported || _initialized) return Future.value();
    return _initializing ??= _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings("@mipmap/ic_launcher"),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _l10n.appUpdateNotificationChannelName,
          importance: Importance.low,
        ),
      );
      _initialized = true;
    } on Object catch (e) {
      warning("Failed to initialize update notifications: $e");
    }
  }

  @override
  Future<bool> ensurePermission() async {
    if (!_supported) return false;
    await initialize();
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } on Object catch (e) {
      warning("Failed to request notification permission: $e");
      return false;
    }
  }

  @override
  Future<void> showDownloadProgress({required int receivedBytes, required int totalBytes}) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    final l10n = _l10n;
    final determinate = totalBytes > 0;
    await _show(
      title: l10n.appUpdateNotificationDownloadTitle,
      body: determinate
          ? l10n.appReleaseUpdateDownloadProgress(
              received: formatUpdateBytes(receivedBytes),
              total: formatUpdateBytes(totalBytes),
            )
          : formatUpdateBytes(receivedBytes),
      details: AndroidNotificationDetails(
        _channelId,
        l10n.appUpdateNotificationChannelName,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: determinate ? totalBytes : 0,
        progress: determinate ? receivedBytes : 0,
        indeterminate: !determinate,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(_cancelActionId, l10n.appReleaseUpdateCancel),
        ],
      ),
    );
  }

  @override
  Future<void> showReadyToInstall({required String version}) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    final l10n = _l10n;
    await _show(
      title: l10n.appUpdateNotificationReadyTitle,
      body: l10n.appUpdateNotificationReadyBody(version: version),
      payload: _installPayload,
      details: AndroidNotificationDetails(
        _channelId,
        l10n.appUpdateNotificationChannelName,
        importance: Importance.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(_installActionId, l10n.appReleaseUpdateInstall),
        ],
      ),
    );
  }

  @override
  Future<void> showFailed() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    final l10n = _l10n;
    await _show(
      title: l10n.appUpdateNotificationFailedTitle,
      body: null,
      details: AndroidNotificationDetails(
        _channelId,
        l10n.appUpdateNotificationChannelName,
        importance: Importance.high,
      ),
    );
  }

  @override
  Future<void> dismiss() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: _notificationId);
    } on Object catch (e) {
      warning("Failed to dismiss update notification: $e");
    }
  }

  Future<void> _show({
    required String title,
    required String? body,
    required AndroidNotificationDetails details,
    String? payload,
  }) async {
    try {
      await _plugin.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: details),
        payload: payload,
      );
    } on Object catch (e) {
      warning("Failed to show update notification: $e");
    }
  }

  void _handleResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == _cancelActionId) {
      onCancelRequested?.call();
      return;
    }
    if (actionId == _installActionId || response.payload == _installPayload) {
      onInstallRequested?.call();
    }
  }
}
