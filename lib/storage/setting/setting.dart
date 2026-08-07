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
abstract class AiChatModel with _$AiChatModel {
  const factory AiChatModel({required String id, String? ownedBy}) = _AiChatModel;

  factory AiChatModel.fromJson(Map<String, dynamic> json) => _$AiChatModelFromJson(json);
}

List<AiChatModel> _aiChatModelsFromJson(List<dynamic> json) => [
  for (final entry in json)
    if (entry is String)
      AiChatModel(id: entry)
    else
      AiChatModel.fromJson((entry as Map).cast<String, dynamic>()),
];

List<dynamic> _aiChatModelsToJson(List<AiChatModel> models) => [
  for (final model in models) model.toJson(),
];

@freezed
abstract class AiChatSetting with _$AiChatSetting {
  const factory AiChatSetting({
    @Default("https://api.openai.com/v1") String baseUrl,
    @Default("gpt-4o-mini") String model,
    @_AiChatModelsConverter()
    @Default([AiChatModel(id: "gpt-4o-mini"), AiChatModel(id: "gpt-4o")])
    List<AiChatModel> models,
  }) = _AiChatSetting;

  factory AiChatSetting.fromJson(Map<String, dynamic> json) => _$AiChatSettingFromJson(json);
}

class _AiChatModelsConverter implements JsonConverter<List<AiChatModel>, List<dynamic>> {
  const _AiChatModelsConverter();

  @override
  List<AiChatModel> fromJson(List<dynamic> json) => _aiChatModelsFromJson(json);

  @override
  List<dynamic> toJson(List<AiChatModel> models) => _aiChatModelsToJson(models);
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
    @Default(AiChatSetting()) AiChatSetting aiChat,
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
