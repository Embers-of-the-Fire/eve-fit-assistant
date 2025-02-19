import 'dart:convert';

import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/v4.dart';

part 'fit_record.g.dart';

@JsonSerializable()
class FitRecordBrief {
  final String id;
  String name;
  String description;
  final int shipID;
  final int createTime;
  int lastModifyTime;

  FitRecordBrief({
    required this.id,
    required this.name,
    required this.description,
    required this.shipID,
    required this.createTime,
    required this.lastModifyTime,
  });

  factory FitRecordBrief.fromJson(Map<String, dynamic> json) => _$FitRecordBriefFromJson(json);

  factory FitRecordBrief.blankNow(String fitName, int shipID) {
    final time = DateTime.now().millisecondsSinceEpoch;
    final id = const UuidV4().generate();
    return FitRecordBrief(
      id: id,
      name: fitName,
      description: '',
      shipID: shipID,
      createTime: time,
      lastModifyTime: time,
    );
  }

  Map<String, dynamic> toJson() => _$FitRecordBriefToJson(this);

  static Future<Map<String, FitRecordBrief>> read() async {
    final briefRecord = await getFitBriefFile(create: true);
    final Map<String, FitRecordBrief> records = {};
    final data = jsonDecode(await briefRecord.readAsString());
    final rec = Map<String, dynamic>.from(data);
    rec.forEach((key, value) {
      records[key] = FitRecordBrief.fromJson(value);
    });
    return records;
  }
}
