import "dart:convert";
import "dart:io";
import "dart:ui" as ui;

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "setting.freezed.dart";
part "setting.g.dart";

@freezed
abstract class RemoteContentSetting with _$RemoteContentSetting {
  const factory RemoteContentSetting({
    @Default(true) bool enabled,
    @Default(false) bool exposed,
    @Default("https://prod.storage.efa-tech.dev") String originUrl,
    @Default("efa/v1/") String resourceRoot,
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
    @JsonKey(defaultValue: true) required bool showBundleImpactWarnings,
    @JsonKey(
      unknownEnumValue: TypeListReturnBehavior.previousPage,
      defaultValue: TypeListReturnBehavior.previousPage,
    )
    required TypeListReturnBehavior typeListReturnBehavior,
    @Default(RemoteContentSetting()) RemoteContentSetting remoteContent,
    String? lastNotifiedBundleUpdateKey,
  }) = _AppSetting;

  factory AppSetting.fromJson(Map<String, dynamic> json) => _$AppSettingFromJson(json);
}

@riverpodSingleton
Locale locale(Ref ref) => ref.watch(appSettingServiceProvider).locale;

@riverpodSingleton
class AppSettingService extends _$AppSettingService {
  static const String _settingFile = "settings.json";
  static File get settingFile => File(p.join(PathProvider.settingsPath, _settingFile));
  static late AppSetting _appSetting;
  static AppSetting get appSetting => _appSetting;

  static void init() {
    _readFromDisk();
    _syncToDisk();
  }

  @override
  AppSetting build() => _appSetting;

  void update(AppSetting Function(AppSetting) updater) {
    _appSetting = updater(_appSetting);
    _syncToDisk();
    state = _appSetting;
  }

  static void _syncToDisk() {
    final text = jsonEncode(_appSetting.toJson());
    if (!settingFile.existsSync()) {
      settingFile.createSync(recursive: true);
    }
    settingFile.writeAsStringSync(text);
  }

  static void _readFromDisk() {
    final Map<String, dynamic> json;
    if (settingFile.existsSync()) {
      final content = settingFile.readAsStringSync();
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
