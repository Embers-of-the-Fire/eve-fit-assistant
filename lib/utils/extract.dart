import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:eve_fit_assistant/config/loading.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

Future<void> extractIsolated(String archivePath, String outputPath) async {
  final receivePort = ReceivePort();
  final loadingKey = "extract-$archivePath-$outputPath";

  GlobalLoading.add(loadingKey, "Extracting ${p.basename(archivePath)}");

  await compute((args) async {
    final [archivePath, outputPath, port] = args;
    int s = 0;
    try {
      await extractFileToDisk(
        archivePath as String,
        outputPath as String,
        callback: (file) {
          if (file.isFile) {
            (port as SendPort).send(file.name);
            s += 1;
          }
        },
      );
      debugPrint("Finished inner extraction");
    } catch (e) {
      debugPrint("Extraction Error: $e");
      rethrow;
    }
    debugPrint("Extracted $s files");
  }, [archivePath, outputPath, receivePort.sendPort]);

  GlobalLoading.dismiss("$loadingKey-progress");
  GlobalLoading.dismiss(loadingKey);
}
