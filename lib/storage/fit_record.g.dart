// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fit_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FitRecordBrief _$FitRecordBriefFromJson(Map<String, dynamic> json) =>
    FitRecordBrief(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      shipID: (json['shipID'] as num).toInt(),
    );

Map<String, dynamic> _$FitRecordBriefToJson(FitRecordBrief instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'shipID': instance.shipID,
    };
