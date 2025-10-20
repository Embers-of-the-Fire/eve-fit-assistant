import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/data/proto/localizations.pb.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "localization.freezed.dart";
part "localization.g.dart";

@freezed
abstract class BundleLocalization with _$BundleLocalization {
  const factory BundleLocalization({required String locale, required Localization localization}) =
      _BundleLocalization;

  static Future<BundleLocalization> loadFromPath(String locale, String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception("Localization file not found: $path");
    }
    final bytes = await file.readAsBytes();
    final localization = Localization.fromBuffer(bytes);
    return BundleLocalization(locale: locale, localization: localization);
  }
}

@riverpod
Future<String?> localization(Ref ref, int key) => ref
    .watch(bundleLocalizationProvider.future)
    .then((data) => data.localization.localizedStrings[key]);

@riverpodSingleton
Future<BundleLocalization> bundleLocalization(Ref ref) {
  final locale = ref.watch(localeProvider).name;
  final locPath = ref.watch(localizationPathProvider(locale));
  return BundleLocalization.loadFromPath(locale, locPath);
}
