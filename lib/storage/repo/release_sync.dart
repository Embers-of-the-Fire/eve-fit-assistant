import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
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

/// Checks for newer APK releases against the remote release index.
///
/// Follows agent/schemav2/workflow.md §13.4.
class ReleaseSyncService {
  const ReleaseSyncService({
    required this.remoteCatalogService,
    this.currentVersionProvider = readFullAppVersion,
  });

  final RemoteCatalogService remoteCatalogService;
  final Future<String> Function() currentVersionProvider;

  Future<Either<ReleaseSyncError, Option<AppRelease>>> check({
    required Channel channel,
    required String generationHash,
  }) async {
    // Step 1: Get the release snapshot hash via GenerationPointer
    final pointerResult = await remoteCatalogService.fetchGenerationPointer(generationHash);
    if (pointerResult.isLeft()) {
      final err = pointerResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch generation pointer";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    final pointer = GenerationPointer.fromBuffer(pointerResult.getRight().toNullable()!);
    final snapshotHash = pointer.snapshotHash;
    if (snapshotHash.isEmpty) {
      return const Left(ReleaseSyncNetworkError(message: "Release pointer has no snapshot hash"));
    }

    // Step 2: Fetch ReleaseIndex
    final indexResult = await remoteCatalogService.fetchReleaseIndex(snapshotHash);
    if (indexResult.isLeft()) {
      final err = indexResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch release index";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    final index = ReleaseIndex.fromBuffer(indexResult.getRight().toNullable()!);

    final installedVersionRaw = await currentVersionProvider();
    final installedVersion = _stripBuildMetadata(installedVersionRaw);

    if (_compareVersions(installedVersion, installedVersion) == null) {
      return Left(
        ReleaseSyncVersionParseError(
          message: "Installed version is not valid semver: $installedVersion",
        ),
      );
    }

    ReleaseIndex_Entry? newest;
    for (final entry in index.entries) {
      if (entry.offerings.isEmpty) continue;
      if (!entry.offerings.contains("android")) continue;
      final cmp = _compareVersions(entry.version, installedVersion);
      if (cmp == null || cmp <= 0) continue;
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
      Some(
        AppRelease(
          releaseId: newest.id,
          version: newest.version,
          createdAt: "", // ReleaseIndex doesn't have createdAt; we use identHash
        ),
      ),
    );
  }

  /// Downloads a release APK blob.
  Future<Either<ReleaseSyncError, Uint8List>> downloadApk(
    Channel channel,
    String identHash,
    String contentHash,
  ) async {
    final result = await remoteCatalogService.fetchBlob(identHash, contentHash);
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to download APK";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    return Right(result.getRight().toNullable()!);
  }
}

// ── Version comparison helpers (unchanged) ───────────────────────────────────

String _stripBuildMetadata(String version) {
  final plusIndex = version.indexOf("+");
  if (plusIndex == -1) return version;
  return version.substring(0, plusIndex);
}

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
