// ignore_for_file: invalid_annotation_target

import "dart:convert";
import "dart:io";

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
abstract class AppSetting with _$AppSetting {
  const factory AppSetting({
    @JsonKey(unknownEnumValue: Locale.zh, defaultValue: Locale.zh) required Locale locale,
    @JsonKey(defaultValue: false) required bool enableDebugLog,
    @JsonKey(
      unknownEnumValue: TypeListDisplayVariant.marketGroup,
      defaultValue: TypeListDisplayVariant.marketGroup,
    )
    required TypeListDisplayVariant shipSelectListDisplayVariant,
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
    final setting = AppSetting.fromJson(json);
    _appSetting = setting;
  }
}
