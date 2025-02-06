import 'package:json_annotation/json_annotation.dart';

part 'fit_record.g.dart';

@JsonSerializable()
class FitRecordBrief {
  final String id;
  final String name;
  final String description;
  final int shipID;

  const FitRecordBrief({
    required this.id,
    required this.name,
    required this.description,
    required this.shipID,
  });

  set name(String name) => name;
  set description(String description) => description;

  factory FitRecordBrief.fromJson(Map<String, dynamic> json) =>
      _$FitRecordBriefFromJson(json);

  Map<String, dynamic> toJson() => _$FitRecordBriefToJson(this);
}
