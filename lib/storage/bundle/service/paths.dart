import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";

part "paths.g.dart";

@riverpodSingleton
BundleServicePaths? bundlePaths(Ref ref) => ref.watch(currentBundleProvider)?.paths;

@riverpod
String iconPath(Ref ref, int iconId) =>
    ref.watch(bundlePathsProvider.select((t) => t?.getIconPath(iconId) ?? ""));

@riverpod
String graphicPath(Ref ref, int graphicId) =>
    ref.watch(bundlePathsProvider.select((t) => t?.getGraphicPath(graphicId) ?? ""));

@riverpodSingleton
String localizationPath(Ref ref, String locale) =>
    ref.watch(bundlePathsProvider.select((t) => t?.getLocalizationPath(locale) ?? ""));

class BundleServicePaths {
  const BundleServicePaths(this.bundlePath);
  static const String _descriptor = "descriptor.json";
  static const String _registrar = "registrar.json";
  static const String _staticPath = "static";
  static const String _localizationPath = "localization";
  static const String _staticImagesPath = "images";
  static const String _staticImagesIconsPath = "icons";
  static const String _staticImagesGraphicsPath = "graphics";
  static const String _staticNativePath = "native";
  static const String _staticCollection = "collection.pb2";
  final String bundlePath;

  static String descriptorPathFromExternalBundle(String bundlePath) =>
      p.join(bundlePath, _descriptor);

  Future<IList<BundleValidationError>> validate() async {
    Future<BundleValidationError?> validateForSingle(
      String filePath, {
      required bool shouldBeFile,
    }) async {
      final realPath = p.join(bundlePath, filePath);
      final isFile = File(realPath).existsSync();
      final isDir = Directory(realPath).existsSync();
      if (!isFile && !isDir) {
        warning("Path not found: $realPath");
        return BundleValidationError.missingPath(path: filePath);
      } else if (shouldBeFile && !isFile) {
        warning("Path is not file: $realPath");
        return BundleValidationError.expectFile(fileName: filePath);
      } else if (!shouldBeFile && !isDir) {
        warning("Path is not directory: $realPath");
        return BundleValidationError.expectDirectory(dirName: filePath);
      }
      return null;
    }

    final validated = await Future.wait(
      [
        (_descriptor, true),
        (_staticPath, false),
        (_localizationPath, false),
        (p.join(_staticPath, _staticNativePath), false),
        (p.join(_staticPath, _staticCollection), true),
        (p.join(_staticPath, _staticImagesPath), false),
        (p.join(_staticPath, _staticImagesPath, _staticImagesIconsPath), false),
        (p.join(_staticPath, _staticImagesPath, _staticImagesGraphicsPath), false),
      ].map((v) => validateForSingle(v.$1, shouldBeFile: v.$2)),
    );

    return validated.filterNull().toIList();
  }

  String getDescriptorPath() => p.join(bundlePath, _descriptor);
  String getRegistrarPath() => p.join(bundlePath, _registrar);

  String getIconPath(int iconId) {
    final iconPath = p.join(
      bundlePath,
      _staticPath,
      _staticImagesPath,
      _staticImagesIconsPath,
      "$iconId.png",
    );
    assert(
      (() {
        final existence = File(iconPath).existsSync();
        if (!existence) {
          warning("Icon not found [$iconId]: $iconPath");
        }
        return existence;
      })(),
    );
    return iconPath;
  }

  String getGraphicPath(int graphicId) {
    final graphicPath = p.join(
      bundlePath,
      _staticPath,
      _staticImagesPath,
      _staticImagesGraphicsPath,
      "$graphicId.png",
    );
    assert(
      (() {
        final existence = File(graphicPath).existsSync();
        if (!existence) {
          warning("Graphic not found [$graphicId]: $graphicPath");
        }
        return existence;
      })(),
    );
    return graphicPath;
  }

  String getLocalizationPath(String locale) {
    final locPath = p.join(bundlePath, _localizationPath, "localization_$locale.pb2");
    assert(
      (() {
        final existence = File(locPath).existsSync();
        if (!existence) {
          warning("Locale definition not found [$locale]: $locPath");
        }
        return existence;
      })(),
    );
    return locPath;
  }

  String getNativePath() => p.join(bundlePath, _staticPath, _staticNativePath);

  String getCollectionPath() => p.join(bundlePath, _staticPath, _staticCollection);
}
