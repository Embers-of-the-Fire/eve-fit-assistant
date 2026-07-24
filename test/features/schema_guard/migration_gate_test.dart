import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/schema_guard/migration_gate.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

Map<String, dynamic> _legacyFitJson() => <String, dynamic>{
  "version": 2,
  "fit": <String, dynamic>{
    "metadata": <String, dynamic>{
      "fitId": "fit-1",
      "shipTypeId": 1234,
      "name": "Legacy Fit",
      "lastModified": 100,
      "description": "",
      "bundleId": "Serenity-21.06-EQUINOX",
      "bundleSnapshot": "old-snapshot-hash",
    },
    "body": <String, dynamic>{
      "shipTypeId": 1234,
      "characterId": "predefined_all_5",
      "slots": <String, dynamic>{
        "high": <Map<String, dynamic>>[],
        "medium": <Map<String, dynamic>>[],
        "low": <Map<String, dynamic>>[],
        "rig": <Map<String, dynamic>>[],
        "subsystem": <Map<String, dynamic>>[],
        "service": <Map<String, dynamic>>[],
      },
      "drones": <Map<String, dynamic>>[],
      "fighters": <Map<String, dynamic>>[],
      "implants": <Map<String, dynamic>>[],
      "boosters": <Map<String, dynamic>>[],
      "damageProfile": <String, dynamic>{
        "em": 0.25,
        "explosive": 0.25,
        "kinetic": 0.25,
        "thermal": 0.25,
      },
    },
    "dynamicRegistry": <String, dynamic>{"dynamicItems": <String, dynamic>{}},
  },
};

Map<String, dynamic> _legacyCharacterJson() => <String, dynamic>{
  "characterId": "char-1",
  "name": "Legacy Character",
  "description": "",
  "lastModified": 100,
  "bundleId": "Serenity-21.06-EQUINOX",
  "bundleSnapshot": "old-snapshot-hash",
  "skills": <String, dynamic>{"123": 5},
};

void _writeLegacyFits(String basePath) {
  final dir = Directory(p.join(basePath, "fittings"));
  dir.createSync(recursive: true);
  File(p.join(dir.path, "fit1.json")).writeAsStringSync(jsonEncode(_legacyFitJson()));
}

void _writeLegacyCharacters(String basePath) {
  final dir = Directory(p.join(basePath, "characters"));
  dir.createSync(recursive: true);
  File(p.join(dir.path, "char1.json")).writeAsStringSync(jsonEncode(_legacyCharacterJson()));
}

void _ensureSchemaVersion() {
  final file = File(RepoPaths.schemaVersionPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode({"schemaVersion": 2}));
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_mig_gate_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("MigrationGate fast-path", () {
    late String tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("efa_mig_gate_test_").path;
      PathProvider.documentsPath = tempDir;
      PathProvider.appSupportPath = tempDir;
    });

    tearDown(() {
      final dir = Directory(tempDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    testWidgets("skips scan and calls onMigrationComplete when schema_version.json exists", (
      tester,
    ) async {
      _ensureSchemaVersion();
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData.light()),
      );

      await tester.pump();
      await tester.pump();

      expect(completed, isTrue);
    });

    testWidgets("calls onMigrationComplete after detecting no legacy data", (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData.light()),
      );

      await tester.pump();
      await tester.pump();

      expect(completed, isTrue);
    });

    testWidgets("shows migration prompt when legacy fits exist", (tester) async {
      _writeLegacyFits(tempDir);
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData.light()),
      );

      await tester.pump();
      await tester.pump();

      expect(completed, isFalse);
      expect(find.text("Data Migration Required"), findsOneWidget);
      expect(find.text("Start Migration"), findsOneWidget);
      expect(find.text("Skip Migration"), findsOneWidget);
    });

    testWidgets("shows migration prompt when legacy characters exist", (tester) async {
      _writeLegacyCharacters(tempDir);
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData.light()),
      );

      await tester.pump();
      await tester.pump();

      expect(completed, isFalse);
      expect(find.text("Data Migration Required"), findsOneWidget);
    });

    testWidgets("fast-path overrides legacy data detection — schema_version wins", (tester) async {
      _ensureSchemaVersion();
      _writeLegacyFits(tempDir);
      var completed = false;

      await tester.pumpWidget(
        MigrationGate(onMigrationComplete: () => completed = true, theme: ThemeData.light()),
      );

      await tester.pump();
      await tester.pump();

      expect(completed, isTrue);
    });
  });
}
