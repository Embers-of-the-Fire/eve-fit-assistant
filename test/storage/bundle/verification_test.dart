import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:eve_fit_assistant/storage/bundle/service/paths.dart";
import "package:eve_fit_assistant/storage/bundle/verification.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  group("BundleVerificationService", () {
    late Directory tempDir;
    late Directory bundleDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp("efa_bundle_verification_test_");
      bundleDir = Directory(p.join(tempDir.path, "bundle"));
      await bundleDir.create(recursive: true);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test("validates a healthy bundle", () async {
      await _writeBundle(bundleDir, files: {"static/data.txt": "healthy"});

      final report = await const BundleVerificationService().verifyBundleDirectory(
        "test-bundle",
        bundleDir,
      );

      expect(report.status, BundleVerificationStatus.valid);
      expect(report.issues, isEmpty);
    });

    test("reports a missing manifest", () async {
      final report = await const BundleVerificationService().verifyBundleDirectory(
        "test-bundle",
        bundleDir,
      );

      expect(report.status, BundleVerificationStatus.invalid);
      expect(report.countIssues<BundleVerificationMissingManifest>(), 1);
    });

    test("reports missing and hash mismatched files", () async {
      await _writeBundle(
        bundleDir,
        files: {"static/missing.txt": "missing", "static/edited.txt": "original"},
      );
      await File(p.join(bundleDir.path, "static", "missing.txt")).delete();
      await File(p.join(bundleDir.path, "static", "edited.txt")).writeAsString("edited");

      final report = await const BundleVerificationService().verifyBundleDirectory(
        "test-bundle",
        bundleDir,
      );

      expect(report.status, BundleVerificationStatus.invalid);
      expect(report.countIssues<BundleVerificationMissingFile>(), 1);
      expect(report.countIssues<BundleVerificationHashMismatch>(), 1);
    });

    test("reports extra files as warnings and ignores registrar", () async {
      await _writeBundle(bundleDir, files: {"static/data.txt": "healthy"});
      await File(p.join(bundleDir.path, "static", "extra.txt")).writeAsString("extra");

      final report = await const BundleVerificationService().verifyBundleDirectory(
        "test-bundle",
        bundleDir,
      );

      expect(report.status, BundleVerificationStatus.warning);
      expect(report.countIssues<BundleVerificationExtraFile>(), 1);
      expect(
        report.issues.whereType<BundleVerificationExtraFile>().single.path,
        "static/extra.txt",
      );
    });
  });
}

Future<void> _writeBundle(Directory bundleDir, {required Map<String, String> files}) async {
  final manifestFiles = <Map<String, Object>>[];
  for (final entry in files.entries) {
    final file = File(p.joinAll(<String>[bundleDir.path, ...entry.key.split("/")]));
    await file.parent.create(recursive: true);
    await file.writeAsString(entry.value);
    manifestFiles.add({
      "path": entry.key,
      "size": await file.length(),
      "sha256": sha256.convert(await file.readAsBytes()).toString(),
    });
  }

  final manifestContent = const JsonEncoder.withIndent("    ").convert({
    "schemaVersion": 1,
    "bundleId": "test-bundle",
    "generateTimestamp": 1,
    "files": manifestFiles,
  });
  await File(p.join(bundleDir.path, "manifest.json")).writeAsString(manifestContent);
  await File(p.join(bundleDir.path, BundleServicePaths.registrarFileName)).writeAsString(
    jsonEncode({
      "bundleId": "test-bundle",
      "history": [
        {
          "appVersion": "0.0.1+1",
          "generateTimestamp": 1,
          "loadTimestamp": 1,
          "gameVersion": "test",
          "gameBuild": "test",
          "gameRegion": "test",
          "gameBranch": "test",
          "gameServer": "test",
          "isIncremental": false,
          "manifestHash": sha256.convert(utf8.encode(manifestContent)).toString(),
        },
      ],
    }),
  );
}
