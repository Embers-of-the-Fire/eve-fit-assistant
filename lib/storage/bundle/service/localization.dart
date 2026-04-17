import "dart:async";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
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

  static Future<Localization> _readLocalizationFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception("Localization file not found: $path");
    }
    final bytes = await file.readAsBytes();
    return Localization.fromBuffer(bytes);
  }

  static Future<BundleLocalization> load({
    required String locale,
    required String path,
    String? fallbackPath,
  }) async {
    final primaryLocalization = await _readLocalizationFile(path);
    final mergedLocalization = Localization();

    if (fallbackPath != null && fallbackPath != path) {
      final fallbackLocalization = await _readLocalizationFile(fallbackPath);
      mergedLocalization.localizedStrings.addAll(fallbackLocalization.localizedStrings);
    }

    mergedLocalization.localizedStrings.addAll(primaryLocalization.localizedStrings);
    return BundleLocalization(locale: locale, localization: mergedLocalization);
  }
}

@riverpod
String? localization(Ref ref, int key) =>
    ref.watch(bundleLocalizationProvider).value?.localization.localizedStrings[key];

@riverpodSingleton
Future<BundleLocalization> bundleLocalization(Ref ref) {
  final requestedLocale = ref.watch(localeProvider).name;
  final bundlePaths = ref.watch(bundlePathsProvider);
  if (bundlePaths == null) {
    debug("Bundle localization unavailable while no bundle paths are active");
    return Future.value(BundleLocalization(locale: requestedLocale, localization: Localization()));
  }

  final resolution = bundlePaths.resolveLocalizationPath(requestedLocale);

  if (resolution == null) {
    warning("Localization path not found for locale: $requestedLocale");
    return Future.value(BundleLocalization(locale: requestedLocale, localization: Localization()));
  }

  final fallbackPath = bundlePaths.tryGetLocalizationPath(
    BundleServicePaths.fallbackLocalizationLocale,
  );
  return BundleLocalization.load(
    locale: resolution.locale,
    path: resolution.path,
    fallbackPath: fallbackPath,
  );
}
