import 'dart:developer' as dev;

import 'package:archive/archive_io.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

Future<void> unpackBundledStorage({
  bool showLoading = false,
  bool autoDismiss = true,
}) async {
  if (showLoading) {
    EasyLoading.show(status: '正在解压静态资产');
  }
  final start = DateTime.now();
  dev.log(
    'unpackBundledStorage',
    name: 'storage',
    time: start,
  );

  final storageDir = await getStaticStorageDir(create: true);
  final storageBundle = await getStorageBundle();
  final gz = const GZipDecoder().decodeBytes(storageBundle.buffer.asUint8List());
  final tar = TarDecoder().decodeBytes(gz);
  await extractArchiveToDisk(tar, storageDir.path);

  final end = DateTime.now();
  dev.log(
    'unpackBundledStorage done in ${end.difference(start).inSeconds}s',
    name: 'storage',
    time: end,
  );
  if (showLoading && autoDismiss) {
    EasyLoading.dismiss();
  }
}

Future<ByteData> getStorageBundle() async {
  final bundle = rootBundle.load('data/storage.tar.gz');
  return bundle;
}

Future<void> clearStaticStorage() async {
  final dir = await getStaticStorageDir();
  await dir.delete(recursive: true);
}
