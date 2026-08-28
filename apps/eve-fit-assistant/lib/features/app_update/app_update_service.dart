import "dart:async";

import "package:convert/convert.dart";
import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:efa_compat/io.dart";
import "package:efa_proto/release_index.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter/services.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

sealed class AppUpdateError implements Exception {
  const AppUpdateError();
}

class AppUpdateNoArtifactError extends AppUpdateError {
  const AppUpdateNoArtifactError({required this.message});

  final String message;

  @override
  String toString() => message;
}

class AppUpdateDownloadError extends AppUpdateError {
  const AppUpdateDownloadError({required this.message});

  final String message;

  @override
  String toString() => message;
}

class AppUpdateCancelledError extends AppUpdateError {
  const AppUpdateCancelledError();

  @override
  String toString() => "Download cancelled";
}

class AppUpdateVerifyError extends AppUpdateError {
  const AppUpdateVerifyError({required this.message});

  final String message;

  @override
  String toString() => message;
}

class AppUpdateInstallError extends AppUpdateError {
  const AppUpdateInstallError({required this.message});

  final String message;

  @override
  String toString() => message;
}

class AppUpdatePermissionError extends AppUpdateError {
  const AppUpdatePermissionError({required this.message});

  final String message;

  @override
  String toString() => message;
}

final RegExp _contentRangePattern = RegExp(r"^bytes\s+(\d+)-\d+/(\d+|\*)$");

int? _contentRangeStart(String? header) {
  if (header == null) return null;
  final match = _contentRangePattern.firstMatch(header.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

/// Platform API for Android install-related operations.
abstract class AppUpdatePlatform {
  const AppUpdatePlatform();

  Future<List<String>> getSupportedAbis();

  Future<bool> canRequestPackageInstalls();

  Future<void> openInstallPermissionSettings();

  Future<void> installApk(String apkPath);
}

/// Information needed to download a specific Android artifact variant.
class AppUpdateArtifact {
  const AppUpdateArtifact({
    required this.variant,
    required this.identifier,
    required this.contentHash,
    required this.size,
  });

  final String variant;
  final String identifier;
  final String contentHash;
  final int size;
}

/// Coordinates download, verification, and installation of Android APK updates.
class AppUpdateService {
  AppUpdateService({
    required this.remoteCatalogService,
    this.platform = const _DefaultPlatform(),
    this.dioFactory = _createDownloadDio,
  });

  final RemoteCatalogService remoteCatalogService;
  final AppUpdatePlatform platform;
  final Dio Function() dioFactory;

  /// Picks the best Android artifact variant for this device.
  ///
  /// Returns an [AppUpdateNoArtifactError] when no suitable artifact exists.
  Future<Either<AppUpdateError, AppUpdateArtifact>> resolveArtifact(
    AndroidArtifacts artifacts,
  ) async {
    final supported = await platform.getSupportedAbis();
    if (supported.isEmpty) {
      return const Left(AppUpdateNoArtifactError(message: "No supported ABIs reported by device"));
    }

    final candidates = <_AbiCandidate>[];
    for (final abi in supported) {
      final normalized = abi.toLowerCase();
      if (normalized == "arm64-v8a" && artifacts.hasArm64()) {
        candidates.add(_AbiCandidate(abi: abi, variant: "arm64", artifact: artifacts.arm64));
      } else if ((normalized == "armeabi-v7a" || normalized == "armeabi") && artifacts.hasArmv7()) {
        candidates.add(_AbiCandidate(abi: abi, variant: "armv7", artifact: artifacts.armv7));
      } else if (normalized == "x86_64" && artifacts.hasX64()) {
        candidates.add(_AbiCandidate(abi: abi, variant: "x64", artifact: artifacts.x64));
      }
    }

    if (candidates.isEmpty) {
      if (!artifacts.hasGeneral()) {
        return const Left(
          AppUpdateNoArtifactError(message: "Release has no general APK artifact to fall back to"),
        );
      }
      final general = artifacts.general;
      return Right(
        AppUpdateArtifact(
          variant: "general",
          identifier: general.identifier,
          contentHash: general.contentHash,
          size: general.size.toInt(),
        ),
      );
    }

    final chosen = candidates.first;
    return Right(
      AppUpdateArtifact(
        variant: chosen.variant,
        identifier: chosen.artifact.identifier,
        contentHash: chosen.artifact.contentHash,
        size: chosen.artifact.size.toInt(),
      ),
    );
  }

  /// Resolves the content-addressed download URI for the best-matching
  /// Android artifact variant of [artifacts].
  ///
  /// Intended for manual-download fallbacks: the returned URI can be opened in
  /// a browser on any platform. Returns `null` when no suitable artifact
  /// exists.
  Future<Uri?> resolveDownloadUri(AndroidArtifacts artifacts) async {
    final result = await resolveArtifact(artifacts);
    return result
        .map(
          (artifact) => remoteCatalogService.blobUri(
            RepoHash.hashIdent(artifact.identifier),
            artifact.contentHash,
          ),
        )
        .toNullable();
  }

  /// Downloads and verifies the APK for [artifact] into the app cache.
  ///
  /// Streams the response to disk (never buffering the whole artifact in
  /// memory). A leftover `.part` file from an interrupted attempt is resumed
  /// with an HTTP `Range` request; servers without range support restart the
  /// transfer from scratch. [onProgress] receives cumulative bytes received
  /// and the total artifact size in bytes. Cancelling [cancelToken] aborts the
  /// transfer, keeps the `.part` file for later resume, and returns
  /// [AppUpdateCancelledError].
  Future<Either<AppUpdateError, String>> downloadArtifact(
    AppUpdateArtifact artifact, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      final dir = Directory(_updatesDirPath());
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final fileName = "update-${artifact.contentHash}.apk";
      final apkPath = p.join(dir.path, fileName);
      final apkFile = File(apkPath);
      if (apkFile.existsSync()) {
        final existingLength = apkFile.lengthSync();
        if (existingLength == artifact.size) {
          final verifyResult = await _verifyApk(apkFile.path, artifact.contentHash);
          if (verifyResult.isRight()) {
            onProgress?.call(artifact.size, artifact.size);
            return Right(apkFile.path);
          }
        }
        apkFile.deleteSync();
      }

      final tempPath = "$apkPath.part";
      final tempFile = File(tempPath);

      var resumedBytes = 0;
      if (tempFile.existsSync()) {
        final partialLength = tempFile.lengthSync();
        if (partialLength > artifact.size) {
          // Cannot belong to this artifact; start over.
          tempFile.deleteSync();
        } else if (partialLength == artifact.size) {
          // Transfer completed but the rename was interrupted.
          tempFile.renameSync(apkFile.path);
          final verifyResult = await _verifyApk(apkFile.path, artifact.contentHash);
          if (verifyResult.isRight()) {
            onProgress?.call(artifact.size, artifact.size);
            return Right(apkFile.path);
          }
          apkFile.deleteSync();
        } else {
          resumedBytes = partialLength;
        }
      }

      final dio = dioFactory();
      final uri = remoteCatalogService.blobUri(
        RepoHash.hashIdent(artifact.identifier),
        artifact.contentHash,
      );

      IOSink? sink;
      try {
        Future<Response<ResponseBody>> request({int? rangeStart}) => dio.getUri<ResponseBody>(
          uri,
          options: Options(
            responseType: ResponseType.stream,
            headers: <String, dynamic>{
              "Accept-Encoding": "identity",
              if (rangeStart != null) "Range": "bytes=$rangeStart-",
            },
            followRedirects: true,
            validateStatus: (status) => status != null && status >= 200 && status < 300,
          ),
          cancelToken: cancelToken,
        );

        var response = await request(rangeStart: resumedBytes > 0 ? resumedBytes : null);
        var appending = resumedBytes > 0 && response.statusCode == 206;
        final rangeStart = _contentRangeStart(response.headers.value("content-range"));
        if (appending && rangeStart != resumedBytes) {
          appending = false;
          response = await request();
        }

        final body = response.data;
        if (body == null) {
          return const Left(AppUpdateDownloadError(message: "Download returned no data"));
        }
        var received = appending ? resumedBytes : 0;
        sink = tempFile.openWrite(mode: appending ? FileMode.append : FileMode.write);
        onProgress?.call(received, artifact.size);

        try {
          await for (final chunk in body.stream) {
            sink.add(chunk);
            received += chunk.length;
            onProgress?.call(received, artifact.size);
          }
        } finally {
          await sink.flush();
          await sink.close();
          sink = null;
        }

        if (received != artifact.size) {
          return Left(
            AppUpdateDownloadError(
              message: "Incomplete download: expected ${artifact.size} bytes, got $received",
            ),
          );
        }

        tempFile.renameSync(apkFile.path);

        final verifyResult = await _verifyApk(apkFile.path, artifact.contentHash);
        if (verifyResult.isLeft()) apkFile.deleteSync();
        return verifyResult.fold(Left.new, (_) => Right(apkFile.path));
      } finally {
        if (sink != null) await sink.close();
        dio.close();
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return const Left(AppUpdateCancelledError());
      return Left(AppUpdateDownloadError(message: "Download failed: ${e.message ?? e.toString()}"));
    } on FileSystemException catch (e) {
      return Left(AppUpdateDownloadError(message: "File system error: ${e.message}"));
    } on AppUpdateError catch (e) {
      return Left(e);
    } on Exception catch (e) {
      return Left(AppUpdateDownloadError(message: "Unexpected error: $e"));
    }
  }

  /// Verifies that the file at [apkPath] matches [expectedContentHash].
  Future<Either<AppUpdateError, Unit>> verifyArtifact(
    String apkPath,
    String expectedContentHash,
  ) async {
    try {
      return await _verifyApk(apkPath, expectedContentHash);
    } on Exception catch (e) {
      return Left(AppUpdateVerifyError(message: "Verification failed: $e"));
    }
  }

  /// Returns whether the app can request package install permissions.
  Future<bool> canInstall() => platform.canRequestPackageInstalls();

  /// Opens Android settings so the user can grant install permission.
  Future<Either<AppUpdateError, Unit>> openInstallPermissionSettings() async {
    try {
      await platform.openInstallPermissionSettings();
      return const Right(unit);
    } on Exception catch (e) {
      return Left(AppUpdatePermissionError(message: "Could not open settings: $e"));
    }
  }

  /// Launches the Android package installer for [apkPath].
  Future<Either<AppUpdateError, Unit>> install(String apkPath) async {
    try {
      final allowed = await platform.canRequestPackageInstalls();
      if (!allowed) {
        return const Left(AppUpdatePermissionError(message: "Install permission not granted"));
      }
      await platform.installApk(apkPath);
      return const Right(unit);
    } on PlatformException catch (e) {
      return Left(AppUpdateInstallError(message: "Install failed: ${e.message ?? e.code}"));
    } on Exception catch (e) {
      return Left(AppUpdateInstallError(message: "Install failed: $e"));
    }
  }

  /// Deletes all downloaded update APKs from cache.
  void clearCache() {
    final dir = Directory(_updatesDirPath());
    if (!dir.existsSync()) return;
    for (final entity in dir.listSync()) {
      try {
        entity.deleteSync(recursive: true);
      } on FileSystemException catch (e) {
        warning("Failed to delete update cache entry ${entity.path}: ${e.message}");
      }
    }
  }

  Future<Either<AppUpdateError, Unit>> _verifyApk(String apkPath, String expectedHash) async {
    final file = File(apkPath);
    if (!file.existsSync()) {
      return Left(AppUpdateVerifyError(message: "APK file not found at $apkPath"));
    }

    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);
    await for (final chunk in file.openRead()) {
      input.add(chunk);
    }
    input.close();
    final actual = output.events.single.toString();
    if (actual != expectedHash) {
      return Left(
        AppUpdateVerifyError(message: "APK hash mismatch: expected $expectedHash, got $actual"),
      );
    }
    return const Right(unit);
  }

  String _updatesDirPath() => p.join(PathProvider.cacheResourcesPath, "updates");
}

class _DefaultPlatform extends AppUpdatePlatform {
  const _DefaultPlatform()
    : _channel = const MethodChannel("dev.efa_tech.eve_fit_assistant/installer");

  final MethodChannel _channel;

  @override
  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return <String>[];
    final result = await _channel.invokeMethod<List<dynamic>>("getSupportedAbis");
    return result?.cast<String>() ?? <String>[];
  }

  @override
  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    final result = await _channel.invokeMethod<bool>("canRequestPackageInstalls");
    return result ?? false;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>("openInstallPermissionSettings");
  }

  @override
  Future<void> installApk(String apkPath) async {
    if (!Platform.isAndroid) {
      throw PlatformException(code: "UNSUPPORTED_PLATFORM", message: "APK install is Android-only");
    }
    await _channel.invokeMethod<void>("installApk", <String, dynamic>{"path": apkPath});
  }
}

Dio _createDownloadDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 10),
      headers: <String, dynamic>{"Accept-Encoding": "identity"},
    ),
  );
  configureSystemProxy(dio);
  return dio;
}

class _AbiCandidate {
  _AbiCandidate({required this.abi, required this.variant, required this.artifact});

  final String abi;
  final String variant;
  final AndroidArtifactVariant artifact;
}

class OptionalMethodChannel extends MethodChannel {
  const OptionalMethodChannel(super.name);

  @override
  Future<T?> invokeMethod<T>(String method, [Object? arguments]) async {
    try {
      return await super.invokeMethod<T>(method, arguments);
    } on MissingPluginException catch (_) {
      return null;
    }
  }
}
