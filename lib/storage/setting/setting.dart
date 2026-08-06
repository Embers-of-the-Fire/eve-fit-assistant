import "dart:async";
import "dart:convert";
import "dart:ui" as ui;

import "package:eve_fit_assistant/config/force_column.dart";
import "package:eve_fit_assistant/config/list_tile_anti_scroll.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "setting.freezed.dart";
part "setting.g.dart";

@freezed
abstract class RemoteContentSetting with _$RemoteContentSetting {
  const factory RemoteContentSetting({
    @Default(true) bool enabled,
    @Default(false) bool exposed,
    @Default("https://prod.storage.efa-tech.dev") String originUrl,
    @Default("testing") String channel,
  }) = _RemoteContentSetting;

  factory RemoteContentSetting.fromJson(Map<String, dynamic> json) =>
      _$RemoteContentSettingFromJson(json);
}

@freezed
abstract class AppSetting with _$AppSetting {
  const factory AppSetting({
    @JsonKey(unknownEnumValue: Locale.en) required Locale locale,
    @JsonKey(defaultValue: false) required bool enableDebugLog,
    @JsonKey(
      unknownEnumValue: TypeListDisplayVariant.marketGroup,
      defaultValue: TypeListDisplayVariant.marketGroup,
    )
    required TypeListDisplayVariant shipSelectListDisplayVariant,
    @JsonKey(defaultValue: true) required bool showCheckoutImpactWarnings,
    @JsonKey(
      unknownEnumValue: TypeListReturnBehavior.previousPage,
      defaultValue: TypeListReturnBehavior.previousPage,
    )
    required TypeListReturnBehavior typeListReturnBehavior,
    @JsonKey(defaultValue: false) required bool developerMode,
    @Default(false) bool attributeDebugView,
    @Default(false) bool ignoreBugfixUpdates,
    @Default(false) bool silentUpdate,
    @Default(false) bool welcomeCompleted,
    @Default(RemoteContentSetting()) RemoteContentSetting remoteContent,
    @Default("") String marketServerFallback,
    @Default(1.0) double fontScale,
    @JsonKey(
      unknownEnumValue: ForceColumnSelection.disabled,
      defaultValue: ForceColumnSelection.disabled,
    )
    @Default(ForceColumnSelection.disabled)
    ForceColumnSelection forceColumn,
    @JsonKey(
      unknownEnumValue: ListTileAntiScrollLevel.closed,
      defaultValue: ListTileAntiScrollLevel.closed,
    )
    @Default(ListTileAntiScrollLevel.closed)
    ListTileAntiScrollLevel listTileAntiScrollLevel,
  }) = _AppSetting;

  factory AppSetting.fromJson(Map<String, dynamic> json) => _$AppSettingFromJson(json);
}

@riverpodSingleton
Locale locale(Ref ref) => ref.watch(appSettingServiceProvider).locale;

@riverpodSingleton
double fontScale(Ref ref) => ref.watch(appSettingServiceProvider).fontScale;

@riverpodSingleton
bool developerMode(Ref ref) => ref.watch(appSettingServiceProvider).developerMode;

@riverpodSingleton
bool attributeDebugView(Ref ref) => ref.watch(appSettingServiceProvider).attributeDebugView;

@riverpodSingleton
class AppSettingService extends _$AppSettingService {
  static const String _settingKey = "settings.json";
  static DocStore? _store;
  static Future<void> _pendingSync = Future<void>.value();
  static late AppSetting _appSetting;
  static AppSetting get appSetting => _appSetting;

  /// Loads settings from the platform document store (files on native,
  /// IndexedDB on web) and persists the effective value. Must be awaited
  /// before [appSetting] is trusted.
  static Future<void> init() async {
    final store = createUserDocStore(UserDataDomain.settings);
    await store.init();
    _store = store;
    await _readFromStore();
    await _syncToStore();
  }

  @override
  AppSetting build() => _appSetting;

  void update(AppSetting Function(AppSetting) updater) {
    _appSetting = updater(_appSetting);
    unawaited(_syncToStore());
    state = _appSetting;
  }

  static Future<void> _syncToStore() {
    final store = _store;
    if (store == null) return Future<void>.value();
    final text = jsonEncode(_appSetting.toJson());
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => store.write(_settingKey, text));
    return _pendingSync;
  }

  static Future<void> _readFromStore() async {
    final store = _store;
    final Map<String, dynamic> json;
    final content = store == null ? null : await store.read(_settingKey);
    if (content != null) {
      json = ensure(jsonDecode(content), {});
    } else {
      json = {};
    }
    final setting = AppSetting.fromJson({"locale": _defaultLocale().name, ...json});
    _appSetting = setting;
  }

  static Locale _defaultLocale() {
    final platformLocale = ui.PlatformDispatcher.instance.locale;
    return switch (platformLocale.languageCode) {
      "zh" => Locale.zh,
      _ => Locale.en,
    };
  }
}
