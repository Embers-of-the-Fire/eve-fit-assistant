import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class FitStorage {
  final MapView<String, FitRecordBrief> _briefRecords = MapView({});

  ReadonlyMap<String, FitRecordBrief> get brief => _briefRecords.read;

  Future<FitRecordBrief> _createBriefRecord(String fitName, int shipID) async {
    final FitRecordBrief record = FitRecordBrief.blankNow(fitName, shipID);
    _briefRecords.write[record.id] = record;
    await _saveBriefRecords();
    return record;
  }

  Future<void> _saveBriefRecords() async {
    final records = _briefRecords.read.toJson();
    final file = await getFitBriefFile(create: true);
    await file.writeAsString(jsonEncode(records));
  }

  Future<FitRecord> createFit(String fitName, int shipID) async {
    final recordBrief = await _createBriefRecord(fitName, shipID);
    final fit = FitRecord.init(recordBrief, shipID);
    await fit.save();
    return fit;
  }

  Future<FitRecord> readFit(String id) async {
    final record = await FitRecord.read(id);
    return record;
  }

  Future<void> deleteFit(String id) async {
    await FitRecord.delete(id);
    _briefRecords.write.remove(id);
    await _saveBriefRecords();
  }

  Future<void> save() async {
    await _saveBriefRecords();
  }

  FitStorage();

  Future<void> init() async {
    final records = await FitRecordBrief.read();
    _briefRecords.write.addAll(records);
  }
}



Future<Directory> getFitDir({bool create = false}) async {
  final storageDir = await getStorageDir();
  final shipBriefRecordDir = Directory('${storageDir.path}/fit');
  if (create) {
    if (!await shipBriefRecordDir.exists()) {
      await shipBriefRecordDir.create(recursive: true);
    }
  }
  return shipBriefRecordDir;
}

Future<File> getFitBriefFile({bool create = false}) async {
  final fitDir = await getFitDir();
  final briefRecord = File('${fitDir.path}/brief.json');
  if (create) {
    if (!await briefRecord.exists()) {
      await briefRecord.create(recursive: true);
      await briefRecord.writeAsString('{}');
    }
  }
  return briefRecord;
}

Future<Directory> getFitFullDir({bool create = false}) async {
  final fitDir = await getFitDir();
  final fullRecordDir = Directory('${fitDir.path}/full');
  if (create) {
    if (!await fullRecordDir.exists()) {
      await fullRecordDir.create(recursive: true);
    }
  }
  return fullRecordDir;
}
