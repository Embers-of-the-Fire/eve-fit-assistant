import "dart:async";
import "dart:convert";
import "dart:ui" as ui;

import "package:eve_fit_assistant/config/force_column.dart";
import "package:eve_fit_assistant/config/list_tile_anti_scroll.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/storage/setting/fit_upload_token_store.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod/riverpod.dart" show ProviderListenableSelect;
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

/// Chat completion providers supported by the AI assistant. Each provider
/// keeps its own connection settings; blank `baseUrl`/`model` fall back to
/// these defaults.
enum ChatProvider {
  openAiCompatible(defaultBaseUrl: "https://api.openai.com/v1", defaultModel: "gpt-4o-mini"),
  anthropic(defaultBaseUrl: "https://api.anthropic.com", defaultModel: "claude-sonnet-4-5"),
  deepSeek(defaultBaseUrl: "https://api.deepseek.com", defaultModel: "deepseek-chat");

  const ChatProvider({required this.defaultBaseUrl, required this.defaultModel});

  final String defaultBaseUrl;
  final String defaultModel;
}

/// Per-provider connection settings for the AI assistant.
@freezed
abstract class AiChatConnection with _$AiChatConnection {
  const factory AiChatConnection({
    /// Blank selects the provider's default endpoint.
    @Default("") String baseUrl,

    /// Blank selects the provider's default model.
    @Default("") String model,
    @_AiChatModelsConverter() @Default([]) List<AiChatModel> models,
  }) = _AiChatConnection;

  factory AiChatConnection.fromJson(Map<String, dynamic> json) => _$AiChatConnectionFromJson(json);
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

@Freezed(fromJson: true, toJson: true)
abstract class AiChatSetting with _$AiChatSetting {
  const factory AiChatSetting({
    @JsonKey(unknownEnumValue: ChatProvider.openAiCompatible)
    @Default(ChatProvider.openAiCompatible)
    ChatProvider provider,
    @_AiChatConnectionsConverter() @Default({}) Map<ChatProvider, AiChatConnection> connections,
  }) = _AiChatSetting;

  const AiChatSetting._();

  /// Migrates the legacy flat `{baseUrl, model, models}` shape into the
  /// OpenAI-compatible connection.
  factory AiChatSetting.fromJson(Map<String, dynamic> json) {
    final migrated = Map<String, dynamic>.of(json);
    if (migrated["connections"] is! Map) {
      migrated["connections"] = {
        ChatProvider.openAiCompatible.name: {
          "baseUrl": migrated["baseUrl"] ?? "",
          "model": migrated["model"] ?? "",
          "models": migrated["models"] ?? const <dynamic>[],
        },
      };
    }
    return _$AiChatSettingFromJson(migrated);
  }

  /// The active provider's stored connection (empty when never configured).
  AiChatConnection get connection => connections[provider] ?? const AiChatConnection();

  /// The effective base URL: the stored override or the provider default.
  String get baseUrl {
    final stored = connection.baseUrl.trim();
    return stored.isEmpty ? provider.defaultBaseUrl : stored;
  }

  /// The effective model: the stored override or the provider default.
  String get model {
    final stored = connection.model.trim();
    return stored.isEmpty ? provider.defaultModel : stored;
  }

  /// The active provider's predefined model choices.
  List<AiChatModel> get models => connection.models;

  /// Update one provider's connection, keeping the others untouched.
  AiChatSetting withConnection(
    ChatProvider target,
    AiChatConnection Function(AiChatConnection) update,
  ) => copyWith(
    connections: {...connections, target: update(connections[target] ?? const AiChatConnection())},
  );
}

class _AiChatConnectionsConverter
    implements JsonConverter<Map<ChatProvider, AiChatConnection>, Map<String, dynamic>> {
  const _AiChatConnectionsConverter();

  @override
  Map<ChatProvider, AiChatConnection> fromJson(Map<String, dynamic> json) {
    final result = <ChatProvider, AiChatConnection>{};
    for (final entry in json.entries) {
      final provider = ChatProvider.values.asNameMap()[entry.key];
      if (provider == null) continue;
      result[provider] = AiChatConnection.fromJson(ensure(entry.value, <String, dynamic>{}));
    }
    return result;
  }

  @override
  Map<String, dynamic> toJson(Map<ChatProvider, AiChatConnection> connections) => {
    for (final entry in connections.entries) entry.key.name: entry.value.toJson(),
  };
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
    @Default(false) bool aiAssistantEnabled,
    @Default(false) bool aiAssistantDisclaimerAcked,
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

/// Whether the AI assistant feature is enabled. Gated behind a one-time
/// disclaimer acknowledgement ([AppSetting.aiAssistantDisclaimerAcked]) and,
/// once on, makes the agent resource database a forced checkout dependency.
@riverpodSingleton
bool aiAssistantEnabled(Ref ref) =>
    ref.watch(appSettingServiceProvider.select((s) => s.aiAssistantEnabled));

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
    await _migrateFitUploadToken(json);
    final setting = AppSetting.fromJson({"locale": _defaultLocale().name, ...json});
    _appSetting = setting;
  }

  /// Moves the legacy plain-JSON upload token into platform secure storage.
  /// The returned [json] no longer carries the field, so the next store sync
  /// scrubs it from disk.
  static Future<void> _migrateFitUploadToken(Map<String, dynamic> json) async {
    final legacy = json.remove(FitUploadTokenStore.legacySettingsKey);
    if (legacy is String && legacy.isNotEmpty) {
      final store = FitUploadTokenStore();
      if ((await store.read()).isEmpty) await store.write(legacy);
    }
  }

  static Locale _defaultLocale() {
    final platformLocale = ui.PlatformDispatcher.instance.locale;
    return switch (platformLocale.languageCode) {
      "zh" => Locale.zh,
      _ => Locale.en,
    };
  }
}
