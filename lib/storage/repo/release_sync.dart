import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/release_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_app_release.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fpdart/fpdart.dart";

sealed class ReleaseSyncError implements Exception {
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

/// Tri-state outcome of comparing the installed app version against the
/// remote release index.
sealed class ReleaseCheckStatus {
  const ReleaseCheckStatus();
}

/// The check could not be performed locally (remote content disabled, no
/// configured channel, or no cached release pointer).
class ReleaseCheckUnavailable extends ReleaseCheckStatus {
  const ReleaseCheckUnavailable();
}

/// The installed version matches the latest remote release.
class ReleaseCheckUpToDate extends ReleaseCheckStatus {
  const ReleaseCheckUpToDate();
}

/// The installed version is newer than the latest remote release. This is
/// unexpected (e.g. a dev build) but reported for transparency.
class ReleaseCheckAheadOfRemote extends ReleaseCheckStatus {
  const ReleaseCheckAheadOfRemote({required this.remoteVersion});

  final String remoteVersion;
}

/// A newer release is available on the remote.
class ReleaseCheckUpdateAvailable extends ReleaseCheckStatus {
  const ReleaseCheckUpdateAvailable({required this.release});

  final RemoteAppRelease release;
}

/// Detects whether a newer app release is available against the remote
/// release index. Detection only — does not download or install artifacts.
class ReleaseSyncService {
  const ReleaseSyncService({
    required this.remoteCatalogService,
    this.currentVersionProvider = readFullAppVersion,
  });

  final RemoteCatalogService remoteCatalogService;
  final Future<String> Function() currentVersionProvider;

  /// Checks for a newer release starting from a [generationHash].
  ///
  /// Fetches the generation's release pointer, resolves the release snapshot
  /// hash, then delegates to [checkFromSnapshotHash].
  Future<Either<ReleaseSyncError, Option<RemoteAppRelease>>> check({
    required String generationHash,
  }) async {
    final resolved = await _resolveSnapshotHash(generationHash);
    return resolved.match(
      Left.new,
      (snapshotHash) => checkFromSnapshotHash(snapshotHash: snapshotHash),
    );
  }

  /// Checks for a newer release given an already-resolved release snapshot hash.
  Future<Either<ReleaseSyncError, Option<RemoteAppRelease>>> checkFromSnapshotHash({
    required String snapshotHash,
  }) async {
    final compared = await _compareWithRemote(snapshotHash: snapshotHash);
    return compared.map((result) {
      if (result.cmp == null || result.cmp! <= 0) return const None();
      return Some(
        RemoteAppRelease(
          releaseId: result.index.id,
          version: result.index.version,
          snapshotHash: snapshotHash,
          index: result.index,
        ),
      );
    });
  }

  /// Full tri-state check starting from a [generationHash].
  ///
  /// Unlike [check], this distinguishes "up to date" from "installed version
  /// is newer than the remote release".
  Future<Either<ReleaseSyncError, ReleaseCheckStatus>> checkStatus({
    required String generationHash,
  }) async {
    final resolved = await _resolveSnapshotHash(generationHash);
    return resolved.match(
      Left.new,
      (snapshotHash) => checkStatusFromSnapshotHash(snapshotHash: snapshotHash),
    );
  }

  /// Full tri-state check given an already-resolved release snapshot hash.
  Future<Either<ReleaseSyncError, ReleaseCheckStatus>> checkStatusFromSnapshotHash({
    required String snapshotHash,
  }) async {
    final compared = await _compareWithRemote(snapshotHash: snapshotHash);
    return compared.map((result) {
      final cmp = result.cmp;
      if (cmp == null || cmp == 0) return const ReleaseCheckUpToDate();
      if (cmp < 0) return ReleaseCheckAheadOfRemote(remoteVersion: result.index.version);
      return ReleaseCheckUpdateAvailable(
        release: RemoteAppRelease(
          releaseId: result.index.id,
          version: result.index.version,
          snapshotHash: snapshotHash,
          index: result.index,
        ),
      );
    });
  }

  /// Resolves the release snapshot hash for [generationHash] by fetching its
  /// generation pointer.
  Future<Either<ReleaseSyncError, String>> _resolveSnapshotHash(String generationHash) async {
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
    return Right(snapshotHash);
  }

  /// Fetches the release index for [snapshotHash] and compares its version
  /// against the installed version.
  ///
  /// The comparison result follows the semantics of [_compareVersions] applied
  /// as `remote.compareTo(installed)`: positive when the remote is newer, zero
  /// when equal, negative when the installed version is newer, and `null` when
  /// the versions cannot be compared. An unparseable installed or remote
  /// version instead yields a [ReleaseSyncVersionParseError].
  Future<Either<ReleaseSyncError, ({ReleaseIndex index, int? cmp})>> _compareWithRemote({
    required String snapshotHash,
  }) async {
    final indexResult = await remoteCatalogService.fetchReleaseIndex(snapshotHash);
    if (indexResult.isLeft()) {
      final err = indexResult.getLeft().toNullable()!;
      final msg = err is CatalogNetworkError ? err.message : "Failed to fetch release index";
      return Left(ReleaseSyncNetworkError(message: msg));
    }
    final index = ReleaseIndex.fromBuffer(indexResult.getRight().toNullable()!);

    final installedVersionRaw = await currentVersionProvider();
    final installedVersion = _stripBuildMetadata(installedVersionRaw);

    if (!_isValidVersion(installedVersion)) {
      return Left(
        ReleaseSyncVersionParseError(
          message: "Installed version is not valid semver: $installedVersion",
        ),
      );
    }

    final remoteVersion = _stripBuildMetadata(index.version);
    if (!_isValidVersion(remoteVersion)) {
      return Left(
        ReleaseSyncVersionParseError(message: "Remote version is not valid semver: $remoteVersion"),
      );
    }

    final cmp = _compareVersions(remoteVersion, installedVersion);
    return Right((index: index, cmp: cmp));
  }
}

// ── Version comparison helpers ───────────────────────────────────────────────

String _stripBuildMetadata(String version) {
  final plusIndex = version.indexOf("+");
  if (plusIndex == -1) return version;
  return version.substring(0, plusIndex);
}

bool _isValidVersion(String version) {
  final core = _stripVPrefix(version).split("-")[0].split(".");
  for (var i = 0; i < 3; i++) {
    final segment = i < core.length ? core[i] : "0";
    if (int.tryParse(segment) == null) return false;
  }
  return true;
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
