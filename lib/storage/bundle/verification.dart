import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/schema_version.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/utils/type_check.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:path/path.dart" as p;

const Set<String> _ignoredExtraBundleFiles = <String>{
  "deleted_files.json",
  "descriptor.json",
  "manifest.json",
  BundleServicePaths.registrarFileName,
};

class BundleManifestFile {
  const BundleManifestFile({required this.path, required this.size, required this.sha256});

  factory BundleManifestFile.fromJson(Map<String, dynamic> json) => BundleManifestFile(
    path: _readRequiredString(json, "path"),
    size: _readRequiredInt(json, "size"),
    sha256: _readRequiredString(json, "sha256"),
  );

  final String path;
  final int size;
  final String sha256;
}

class BundleSnapshotManifest {
  const BundleSnapshotManifest({
    required this.bundleSchemaVersion,
    required this.compatibleBundleSchemaVersions,
    required this.bundleId,
    required this.generateTimestamp,
    required this.files,
  });

  factory BundleSnapshotManifest.fromJson(Map<String, dynamic> json) {
    final rawFiles = json["files"];
    if (rawFiles is! List<Object?>) {
      throw const FormatException("Manifest field 'files' must be a list.");
    }
    return BundleSnapshotManifest(
      bundleSchemaVersion: _readBundleSchemaVersion(json),
      compatibleBundleSchemaVersions: _readCompatibleBundleSchemaVersions(json),
      bundleId: _readRequiredString(json, "bundleId"),
      generateTimestamp: _readRequiredInt(json, "generateTimestamp"),
      files: rawFiles.map((rawFile) {
        if (rawFile is! Map<String, dynamic>) {
          throw const FormatException("Manifest file entry must be an object.");
        }
        return BundleManifestFile.fromJson(rawFile);
      }).toIList(),
    );
  }

  final int bundleSchemaVersion;
  final IList<int> compatibleBundleSchemaVersions;
  final String bundleId;
  final int generateTimestamp;
  final IList<BundleManifestFile> files;
}

enum BundleVerificationStatus { valid, warning, invalid }

sealed class BundleVerificationIssue {
  const BundleVerificationIssue();

  String? get path => null;
}

class BundleVerificationMissingManifest extends BundleVerificationIssue {
  const BundleVerificationMissingManifest({required this.path});

  @override
  final String path;
}

class BundleVerificationInvalidManifest extends BundleVerificationIssue {
  const BundleVerificationInvalidManifest({required this.path, required this.error});

  @override
  final String path;
  final String error;
}

class BundleVerificationManifestHashMissing extends BundleVerificationIssue {
  const BundleVerificationManifestHashMissing();
}

class BundleVerificationManifestHashMismatch extends BundleVerificationIssue {
  const BundleVerificationManifestHashMismatch({required this.expected, required this.actual});

  final String expected;
  final String actual;
}

class BundleVerificationUnsafeManifestPath extends BundleVerificationIssue {
  const BundleVerificationUnsafeManifestPath({required this.path});

  @override
  final String path;
}

class BundleVerificationMissingFile extends BundleVerificationIssue {
  const BundleVerificationMissingFile({required this.path});

  @override
  final String path;
}

class BundleVerificationSizeMismatch extends BundleVerificationIssue {
  const BundleVerificationSizeMismatch({
    required this.path,
    required this.expected,
    required this.actual,
  });

  @override
  final String path;
  final int expected;
  final int actual;
}

class BundleVerificationHashMismatch extends BundleVerificationIssue {
  const BundleVerificationHashMismatch({
    required this.path,
    required this.expected,
    required this.actual,
  });

  @override
  final String path;
  final String expected;
  final String actual;
}

class BundleVerificationExtraFile extends BundleVerificationIssue {
  const BundleVerificationExtraFile({required this.path});

  @override
  final String path;
}

class BundleVerificationReadError extends BundleVerificationIssue {
  const BundleVerificationReadError({required this.path, required this.error});

  @override
  final String path;
  final String error;
}

class BundleVerificationUnsupportedSchemaVersion extends BundleVerificationIssue {
  const BundleVerificationUnsupportedSchemaVersion({
    required this.bundleVersion,
    required this.supported,
  });

  final int bundleVersion;
  final IList<int> supported;
}

class BundleVerificationSchemaVersionMismatch extends BundleVerificationIssue {
  const BundleVerificationSchemaVersionMismatch({
    required this.bundleVersion,
    required this.current,
  });

  final int bundleVersion;
  final int current;
}

bool _isNonBlocking(BundleVerificationIssue issue) => switch (issue) {
  BundleVerificationExtraFile() ||
  BundleVerificationManifestHashMissing() ||
  BundleVerificationSchemaVersionMismatch() => true,
  _ => false,
};

class BundleVerificationReport {
  const BundleVerificationReport({
    required this.bundleId,
    required this.checkedAt,
    required this.status,
    required this.issues,
  });

  final String bundleId;
  final DateTime checkedAt;
  final BundleVerificationStatus status;
  final IList<BundleVerificationIssue> issues;

  bool get isValid => status == BundleVerificationStatus.valid;

  int countIssues<T extends BundleVerificationIssue>() => issues.whereType<T>().length;

  IList<BundleVerificationIssue> get blockingIssues =>
      issues.where((issue) => !_isNonBlocking(issue)).toIList();

  IList<BundleVerificationIssue> get warningIssues => issues.where(_isNonBlocking).toIList();
}

class BundleVerificationService {
  const BundleVerificationService();

  @visibleForTesting
  Future<BundleVerificationReport> verifyBundleDirectory(String bundleId, Directory bundleRoot) =>
      _verifyBundleDirectory(bundleId, bundleRoot);

  Future<BundleVerificationReport> verifyInstalledBundle(String bundleId) async {
    final bundleRoot = Directory(BundleManager.getBundlePath(bundleId));
    return _verifyBundleDirectory(bundleId, bundleRoot);
  }

  Future<BundleVerificationReport> _verifyBundleDirectory(
    String bundleId,
    Directory bundleRoot,
  ) async {
    final checkedAt = DateTime.now();
    final paths = BundleServicePaths(bundleRoot.path);
    final manifestFile = File(paths.getManifestPath());
    final issues = <BundleVerificationIssue>[];

    if (!manifestFile.existsSync()) {
      issues.add(BundleVerificationMissingManifest(path: manifestFile.path));
      return _buildReport(bundleId: bundleId, checkedAt: checkedAt, issues: issues);
    }

    final String manifestContent;
    final BundleSnapshotManifest manifest;
    try {
      manifestContent = await manifestFile.readAsString();
      manifest = BundleSnapshotManifest.fromJson(ensure(jsonDecode(manifestContent), {}));
    } on Object catch (error) {
      issues.add(
        BundleVerificationInvalidManifest(path: manifestFile.path, error: error.toString()),
      );
      return _buildReport(bundleId: bundleId, checkedAt: checkedAt, issues: issues);
    }

    if (manifest.bundleId != bundleId) {
      issues.add(
        BundleVerificationInvalidManifest(
          path: manifestFile.path,
          error: "Manifest bundle id ${manifest.bundleId} does not match $bundleId.",
        ),
      );
    }

    _verifyManifestHash(bundleId, bundleRoot, manifestContent, issues);
    _verifyManifestSchemaVersion(manifest, issues);
    await _verifyManifestEntries(bundleRoot, manifest, issues);
    await _verifyExtraFiles(bundleRoot, manifest, issues);

    return _buildReport(bundleId: bundleId, checkedAt: checkedAt, issues: issues);
  }

  void _verifyManifestHash(
    String bundleId,
    Directory bundleRoot,
    String manifestContent,
    List<BundleVerificationIssue> issues,
  ) {
    final registrarPath = BundleServicePaths(bundleRoot.path).getRegistrarPath();
    if (!File(registrarPath).existsSync()) {
      issues.add(const BundleVerificationManifestHashMissing());
      return;
    }

    try {
      final content = jsonDecode(File(registrarPath).readAsStringSync());
      final expected = BundleRegistrar.fromJson(ensure(content, {})).latest.manifestHash;
      if (expected == null || expected.isEmpty) {
        issues.add(const BundleVerificationManifestHashMissing());
        return;
      }
      final actual = sha256.convert(utf8.encode(manifestContent)).toString();
      if (actual != expected) {
        issues.add(BundleVerificationManifestHashMismatch(expected: expected, actual: actual));
      }
    } on Object {
      issues.add(const BundleVerificationManifestHashMissing());
    }
  }

  void _verifyManifestSchemaVersion(
    BundleSnapshotManifest manifest,
    List<BundleVerificationIssue> issues,
  ) {
    if (!supportedBundleSchemaVersions.contains(manifest.bundleSchemaVersion)) {
      issues.add(
        BundleVerificationUnsupportedSchemaVersion(
          bundleVersion: manifest.bundleSchemaVersion,
          supported: supportedBundleSchemaVersions,
        ),
      );
    } else if (manifest.bundleSchemaVersion != currentBundleSchemaVersion) {
      issues.add(
        BundleVerificationSchemaVersionMismatch(
          bundleVersion: manifest.bundleSchemaVersion,
          current: currentBundleSchemaVersion,
        ),
      );
    }
  }

  Future<void> _verifyManifestEntries(
    Directory bundleRoot,
    BundleSnapshotManifest manifest,
    List<BundleVerificationIssue> issues,
  ) async {
    for (final entry in manifest.files) {
      final resolvedPath = _resolveBundlePath(bundleRoot, entry.path);
      if (resolvedPath == null) {
        issues.add(BundleVerificationUnsafeManifestPath(path: entry.path));
        continue;
      }

      final file = File(resolvedPath);
      if (!file.existsSync()) {
        issues.add(BundleVerificationMissingFile(path: entry.path));
        continue;
      }

      try {
        final actualSize = await file.length();
        if (actualSize != entry.size) {
          issues.add(
            BundleVerificationSizeMismatch(
              path: entry.path,
              expected: entry.size,
              actual: actualSize,
            ),
          );
        }

        final actualHash = await _fileSha256(file);
        if (actualHash != entry.sha256) {
          issues.add(
            BundleVerificationHashMismatch(
              path: entry.path,
              expected: entry.sha256,
              actual: actualHash,
            ),
          );
        }
      } on Object catch (error) {
        issues.add(BundleVerificationReadError(path: entry.path, error: error.toString()));
      }
    }
  }

  Future<void> _verifyExtraFiles(
    Directory bundleRoot,
    BundleSnapshotManifest manifest,
    List<BundleVerificationIssue> issues,
  ) async {
    final manifestPaths = manifest.files
        .map((entry) => p.posix.normalize(entry.path.replaceAll(r"\", "/")))
        .toSet();
    await for (final entity in bundleRoot.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: bundleRoot.path).replaceAll(r"\", "/");
      if (_ignoredExtraBundleFiles.contains(relativePath) || manifestPaths.contains(relativePath)) {
        continue;
      }
      issues.add(BundleVerificationExtraFile(path: relativePath));
    }
  }

  BundleVerificationReport _buildReport({
    required String bundleId,
    required DateTime checkedAt,
    required List<BundleVerificationIssue> issues,
  }) {
    final status = issues.any((issue) => !_isNonBlocking(issue))
        ? BundleVerificationStatus.invalid
        : issues.isEmpty
        ? BundleVerificationStatus.valid
        : BundleVerificationStatus.warning;
    return BundleVerificationReport(
      bundleId: bundleId,
      checkedAt: checkedAt,
      status: status,
      issues: issues.lock,
    );
  }

  String? _resolveBundlePath(Directory bundleRoot, String relativePath) {
    final normalized = relativePath.trim().replaceAll(r"\", "/");
    final parsed = Uri.tryParse(normalized);
    if (normalized.isEmpty ||
        normalized.startsWith("/") ||
        parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority) {
      return null;
    }

    final parts = normalized.split("/");
    if (parts.any((part) => part.isEmpty || part == "." || part == "..")) {
      return null;
    }
    if (parts.any((part) => Uri.decodeComponent(part).contains(".."))) {
      return null;
    }

    final rootPath = p.normalize(p.absolute(bundleRoot.path));
    final resolvedPath = p.normalize(p.absolute(p.joinAll(<String>[bundleRoot.path, ...parts])));
    if (!p.isWithin(rootPath, resolvedPath)) {
      return null;
    }
    return resolvedPath;
  }

  Future<String> _fileSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

int _readRequiredInt(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! int) {
    throw FormatException("Manifest field '$key' must be an integer.");
  }
  return value;
}

String _readRequiredString(Map<String, dynamic> payload, String key) {
  final value = payload[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException("Manifest field '$key' must be a non-empty string.");
  }
  return value;
}

int _readBundleSchemaVersion(Map<String, dynamic> json) {
  final value = json["bundleSchemaVersion"];
  if (value is int) return value;
  final oldValue = json["schemaVersion"];
  if (oldValue is int) return oldValue;
  return 1;
}

IList<int> _readCompatibleBundleSchemaVersions(Map<String, dynamic> json) {
  final value = json["compatibleBundleSchemaVersions"];
  if (value is List<Object?>) {
    return value.whereType<int>().toIList();
  }
  return IList([_readBundleSchemaVersion(json)]);
}
