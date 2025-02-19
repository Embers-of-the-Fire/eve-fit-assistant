import 'dart:developer' as dev;

import 'package:archive/archive_io.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:eve_fit_assistant/widgets/loading.dart';
import 'package:flutter/services.dart';

const String _bundleLoadingKey = 'unpack';

Future<void> unpackBundledStorage() async {
  GlobalLoading().add(_bundleLoadingKey, '正在解压静态资产');

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

  GlobalLoading().dismiss(_bundleLoadingKey);
}

Future<ByteData> getStorageBundle() async {
  final bundle = rootBundle.load('data/storage.tar.gz');
  return bundle;
}

const String _clearStorageLoadingKey = 'clear';

Future<void> clearStaticStorage() async {
  GlobalLoading().add(_clearStorageLoadingKey, '正在清理旧文件');
  final dir = await getStaticStorageDir();
  await dir.delete(recursive: true);
  GlobalLoading().dismiss(_clearStorageLoadingKey);
}
