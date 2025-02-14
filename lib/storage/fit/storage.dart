import 'dart:convert';

import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/utils/map.dart';

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
    final file = await getBriefRecordFile(create: true);
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

  Future<void> save() async {
    await _saveBriefRecords();
  }

  FitStorage();

  Future<void> init() async {
    final records = await FitRecordBrief.read();
    _briefRecords.write.addAll(records);
  }
}
