// ignore_for_file: invalid_annotation_target

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/static/damage_profile.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'schema.freezed.dart';
part 'schema.g.dart';

@freezed
abstract class FitExport with _$FitExport {
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
    @JsonKey(defaultValue: []) required List<DroneItem> drone,
    @JsonKey(defaultValue: []) required List<FighterItem> fighter,
    @JsonKey(defaultValue: []) required List<SlotItem?> implant,
    @JsonKey(defaultValue: []) required List<SlotItem> booster,
    @JsonKey(defaultValue: {}) required Map<int, DynamicItem> dynamicItems,
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
      booster: fit.body.booster,
      dynamicItems: fit.body.dynamicItems);

  String get encoded {
    final json = jsonEncode(toJson());
    final compressed = const GZipEncoder().encodeBytes(utf8.encode('EFA-EXPORT:$json'), level: 9);
    return base64Encode(compressed);
  }

  static FitExport? fromEncoded(String encoded) {
    late final Uint8List compressed;
    try {
      compressed = base64Decode(encoded);
    } catch (e) {
      return null;
    }
    final json = utf8.decode(const GZipDecoder().decodeBytes(compressed));
    if (json.startsWith('EFA-EXPORT:')) {
      return FitExport.fromJson(jsonDecode(json.replaceFirst('EFA-EXPORT:', '')));
    }
    return null;
  }
}

extension ImportFit on FitStorage {
  Future<FitRecord> importFit(FitExport fit) async {
    final newRecord = await createFit(fit.name, fit.shipID);
    final newBrief = newRecord.brief;
    final copiedRecord = FitRecord(
        brief: FitRecordBrief(
            id: newBrief.id,
            name: fit.name,
            description: fit.description,
            shipID: fit.shipID,
            createTime: newBrief.createTime,
            lastModifyTime: newBrief.lastModifyTime),
        body: Fit(
            shipID: fit.shipID,
            damageProfile: fit.damageProfile,
            high: fit.high,
            med: fit.med,
            low: fit.low,
            rig: fit.rig,
            subsystem: fit.subSystem,
            drone: fit.drone,
            fighter: fit.fighter,
            implant: fit.implant,
            booster: fit.booster,
            tacticalModeID: fit.tacticalModeID,
            dynamicItems: fit.dynamicItems));
    await copiedRecord.save();
    await save();
    return copiedRecord;
  }
}
