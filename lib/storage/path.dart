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
