import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> getStorageDir({bool create = false}) async {
  final Directory appDir = await getApplicationDocumentsDirectory();
  final Directory storageDir = Directory('${appDir.path}/storage');
  if (create) {
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
  }
  return storageDir;
}

Future<Directory> getRecordDir({bool create = false}) async {
  final Directory storageDir = await getStorageDir();
  final Directory shipBriefRecordDir = Directory('${storageDir.path}/record');
  if (create) {
    if (!await shipBriefRecordDir.exists()) {
      await shipBriefRecordDir.create(recursive: true);
    }
  }
  return shipBriefRecordDir;
}

Future<File> getBriefRecordFile({bool create = false}) async {
  final Directory storageDir = await getStorageDir();
  final File briefRecord = File('${storageDir.path}/brief.json');
  if (create) {
    if (!await briefRecord.exists()) {
      await briefRecord.create(recursive: true);
      await briefRecord.writeAsString('{}');
    }
  }
  return briefRecord;
}

Future<Directory> getFullRecordDir({bool create = false}) async {
  final Directory storageDir = await getStorageDir();
  final Directory fullRecordDir = Directory('${storageDir.path}/full');
  if (create) {
    if (!await fullRecordDir.exists()) {
      await fullRecordDir.create(recursive: true);
    }
  }
  return fullRecordDir;
}
