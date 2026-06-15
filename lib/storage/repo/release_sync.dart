import "dart:typed_data";

import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fpdart/fpdart.dart";

sealed class ReleaseSyncError {
  const ReleaseSyncError();
}

class ReleaseSyncNetworkError extends ReleaseSyncError {
  const ReleaseSyncNetworkError({required this.message});

  final String message;
}

class ReleaseSyncVersionParseError extends ReleaseSyncError {
  const ReleaseSyncVersionParseError({required this.message});

  final String message;
}

class AppRelease {
  const AppRelease({required this.releaseId, required this.version, required this.createdAt});

  final String releaseId;
  final String version;
  final String createdAt;
}

class ReleaseSyncService {
  const ReleaseSyncService({
    required this.remoteCatalogService,
    this.currentVersionProvider = readFullAppVersion,
  });

  final RemoteCatalogService remoteCatalogService;
  final Future<String> Function() currentVersionProvider;

  Future<Either<ReleaseSyncError, Option<AppRelease>>> check(Channel channel) async {
    final manifestResult = await remoteCatalogService.fetchManifestIndex(channel);
    if (manifestResult.isLeft()) {
      final err = manifestResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch manifest";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    final generationId = manifestResult.getRight().toNullable()!.activatedGeneration;

    final catalogResult = await remoteCatalogService.fetchReleaseCatalog(channel, generationId);
    if (catalogResult.isLeft()) {
      final err = catalogResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch release catalog";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    final catalog = catalogResult.getRight().toNullable()!;

    final installedVersionRaw = await currentVersionProvider();
    final installedVersion = _stripBuildMetadata(installedVersionRaw);

    // Validate installed version before comparison loop
    if (_compareVersions(installedVersion, installedVersion) == null) {
      return Left(
        ReleaseSyncVersionParseError(
          message: "Installed version is not valid semver: $installedVersion",
        ),
      );
    }

    ReleaseCatalogEntry? newest;
    for (final entry in catalog.releases.values) {
      if (!entry.offering.contains("apk")) continue;
      final cmp = _compareVersions(entry.version, installedVersion);
      if (cmp == null) continue;
      if (cmp <= 0) continue;
      if (newest == null) {
        newest = entry;
        continue;
      }
      final newestCmp = _compareVersions(entry.version, newest.version);
      if (newestCmp != null && newestCmp > 0) {
        newest = entry;
      }
    }

    if (newest == null) return const Right(None());

    return Right(
      Some(AppRelease(releaseId: newest.id, version: newest.version, createdAt: newest.createdAt)),
    );
  }

  Future<Either<ReleaseSyncError, Uint8List>> downloadApk(
    Channel channel,
    String releaseHash,
  ) async {
    final result = await remoteCatalogService.fetchReleaseFile(channel, releaseHash);
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to download APK";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    return Right(result.getRight().toNullable()!);
  }
}

/// Strips build metadata (`+...`) from a full app version string.
String _stripBuildMetadata(String version) {
  final plusIndex = version.indexOf("+");
  if (plusIndex == -1) return version;
  return version.substring(0, plusIndex);
}

/// Compares two semantic version strings (e.g. "2.1.0", "2.1.0-rc1").
///
/// Returns a negative integer if [a] < [b], zero if equal, positive if [a] > [b].
/// Returns `null` if either version has unparseable numeric components.
int? _compareVersions(String a, String b) {
  final aStripped = _stripVPrefix(a);
  final bStripped = _stripVPrefix(b);

  final aParts = aStripped.split("-");
  final bParts = bStripped.split("-");

  final aCore = aParts[0].split(".").map(_parseInt).toList();
  final bCore = bParts[0].split(".").map(_parseInt).toList();

  for (var i = 0; i < 3; i++) {
    final aVal = i < aCore.length ? aCore[i] : 0;
    final bVal = i < bCore.length ? bCore[i] : 0;
    if (aVal == null || bVal == null) return null;
    final cmp = aVal.compareTo(bVal);
    if (cmp != 0) return cmp;
  }

  final aHasPre = aParts.length > 1;
  final bHasPre = bParts.length > 1;

  if (aHasPre && !bHasPre) return -1;
  if (!aHasPre && bHasPre) return 1;

  if (aHasPre && bHasPre) return _comparePrerelease(aParts.sublist(1), bParts.sublist(1));

  return 0;
}

/// Compares prerelease identifiers per semver 2.0 precedence rules.
///
/// Numeric identifiers are compared numerically; non-numeric identifiers are
/// compared lexicographically. Numeric identifiers have lower precedence than
/// non-numeric ones. A shorter set of identifiers has lower precedence than a
/// longer one when all preceding identifiers are equal.
int _comparePrerelease(List<String> aPre, List<String> bPre) {
  final aIds = aPre.join("-").split(".");
  final bIds = bPre.join("-").split(".");

  final len = aIds.length > bIds.length ? aIds.length : bIds.length;
  for (var i = 0; i < len; i++) {
    if (i >= aIds.length) return -1;
    if (i >= bIds.length) return 1;

    final aNum = int.tryParse(aIds[i]);
    final bNum = int.tryParse(bIds[i]);

    if (aNum != null && bNum != null) {
      final cmp = aNum.compareTo(bNum);
      if (cmp != 0) return cmp;
    } else if (aNum != null) {
      return -1;
    } else if (bNum != null) {
      return 1;
    } else {
      final cmp = aIds[i].compareTo(bIds[i]);
      if (cmp != 0) return cmp;
    }
  }

  return 0;
}

String _stripVPrefix(String version) {
  if (version.toLowerCase().startsWith("v")) return version.substring(1);
  return version;
}

int? _parseInt(String s) => int.tryParse(s);
