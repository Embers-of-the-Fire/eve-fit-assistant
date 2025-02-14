import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/storage/path.dart';
import 'package:json_annotation/json_annotation.dart';

part 'version.g.dart';

Future<File> _getVersionFile({bool create = false}) async {
  final Directory storageDir = await getStorageDir(create: create);
  final File versionFile = File('${storageDir.path}/version');
  if (create) {
    if (!await versionFile.exists()) {
      await versionFile.create(recursive: true);
    }
  }
  return versionFile;
}

Future<VersionInfo?> getVersionInfo() async {
  final File versionFile = await _getVersionFile();
  if (!await versionFile.exists()) {
    return null;
  }
  final String versionStr = await versionFile.readAsString();
  return VersionInfo.fromJson(jsonDecode(versionStr));
}

@JsonSerializable()
class VersionInfo {
  /// Version code of the current storage
  /// Note: this is not the same as app's version
  final int version;

  const VersionInfo({required this.version});

  factory VersionInfo.fromJson(Map<String, dynamic> json) => _$VersionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$VersionInfoToJson(this);

  static const VersionInfo currentVersion = VersionInfo(version: 1);

  bool isCompatible() => version == currentVersion.version;

  bool needsMigration() => version < currentVersion.version;

  bool needsUpgrade() => version > currentVersion.version;
}

Future<void> createVersionFile() async {
  final File versionFile = await _getVersionFile(create: true);
  await versionFile.writeAsString(jsonEncode(VersionInfo.currentVersion.toJson()));
}
