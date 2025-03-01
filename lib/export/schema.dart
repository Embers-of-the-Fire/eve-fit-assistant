import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/static/damage_profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'schema.freezed.dart';
part 'schema.g.dart';

@freezed
class FitExport with _$FitExport {
  const factory FitExport({
    required String name,
    required String description,
    required int shipID,
    required DamageProfile damageProfile,
    required List<SlotItem?> high,
    required List<SlotItem?> med,
    required List<SlotItem?> low,
    required List<SlotItem?> rig,
    required List<SlotItem?> subSystem,
    required List<DroneItem> drone,
    required List<FighterItem> fighter,
    required List<SlotItem?> implant,
    required Map<int, DynamicItem> dynamicItems,
    int? tacticalModeID,
  }) = _FitExport;

  const FitExport._();

  factory FitExport.fromJson(Map<String, dynamic> json) => _$FitExportFromJson(json);

  factory FitExport.fromRecord(FitRecord fit) => FitExport(
      name: fit.brief.name,
      description: fit.brief.description,
      shipID: fit.brief.shipID,
      damageProfile: fit.body.damageProfile,
      high: fit.body.high,
      med: fit.body.med,
      low: fit.body.low,
      rig: fit.body.rig,
      subSystem: fit.body.subsystem,
      drone: fit.body.drone,
      fighter: fit.body.fighter,
      implant: fit.body.implant,
      dynamicItems: fit.body.dynamicItems);

  String get encoded {
    final json = jsonEncode(toJson());
    final compressed = const GZipEncoder().encodeBytes(utf8.encode(json), level: 9);
    return base64Encode(compressed);
  }

  factory FitExport.fromEncoded(String encoded) {
    final compressed = base64Decode(encoded);
    final json = utf8.decode(const GZipDecoder().decodeBytes(compressed));
    return FitExport.fromJson(jsonDecode(json));
  }
}
