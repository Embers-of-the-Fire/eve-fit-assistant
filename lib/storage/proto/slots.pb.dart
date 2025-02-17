//
//  Generated code. Do not modify.
//  source: slots.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;
import 'slots.pbenum.dart';

export 'slots.pbenum.dart';

class Slots_HighSlot extends $pb.GeneratedMessage {
  factory Slots_HighSlot({
    $0.I18N? name,
    $core.bool? isTurret,
    $core.bool? isLauncher,
    $core.bool? published,
    Slots_SlotState? maxState,
    $core.Iterable<$core.int>? chargeGroups,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (isTurret != null) {
      $result.isTurret = isTurret;
    }
    if (isLauncher != null) {
      $result.isLauncher = isLauncher;
    }
    if (published != null) {
      $result.published = published;
    }
    if (maxState != null) {
      $result.maxState = maxState;
    }
    if (chargeGroups != null) {
      $result.chargeGroups.addAll(chargeGroups);
    }
    return $result;
  }

  Slots_HighSlot._() : super();

  factory Slots_HighSlot.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory Slots_HighSlot.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Slots.HighSlot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'slots'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.bool>(2, _omitFieldNames ? '' : 'isTurret', $pb.PbFieldType.QB, protoName: 'isTurret')
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'isLauncher', $pb.PbFieldType.QB,
        protoName: 'isLauncher')
    ..a<$core.bool>(4, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..e<Slots_SlotState>(5, _omitFieldNames ? '' : 'maxState', $pb.PbFieldType.QE,
        protoName: 'maxState',
        defaultOrMaker: Slots_SlotState.PASSIVE,
        valueOf: Slots_SlotState.valueOf,
        enumValues: Slots_SlotState.values)
    ..p<$core.int>(6, _omitFieldNames ? '' : 'chargeGroups', $pb.PbFieldType.P3,
        protoName: 'chargeGroups');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Slots_HighSlot clone() => Slots_HighSlot()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Slots_HighSlot copyWith(void Function(Slots_HighSlot) updates) =>
      super.copyWith((message) => updates(message as Slots_HighSlot)) as Slots_HighSlot;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Slots_HighSlot create() => Slots_HighSlot._();

  Slots_HighSlot createEmptyInstance() => create();

  static $pb.PbList<Slots_HighSlot> createRepeated() => $pb.PbList<Slots_HighSlot>();

  @$core.pragma('dart2js:noInline')
  static Slots_HighSlot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Slots_HighSlot>(create);
  static Slots_HighSlot? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);

  @$pb.TagNumber(1)
  set name($0.I18N v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);

  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get isTurret => $_getBF(1);

  @$pb.TagNumber(2)
  set isTurret($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasIsTurret() => $_has(1);

  @$pb.TagNumber(2)
  void clearIsTurret() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get isLauncher => $_getBF(2);

  @$pb.TagNumber(3)
  set isLauncher($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasIsLauncher() => $_has(2);

  @$pb.TagNumber(3)
  void clearIsLauncher() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get published => $_getBF(3);

  @$pb.TagNumber(4)
  set published($core.bool v) {
    $_setBool(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasPublished() => $_has(3);

  @$pb.TagNumber(4)
  void clearPublished() => clearField(4);

  @$pb.TagNumber(5)
  Slots_SlotState get maxState => $_getN(4);

  @$pb.TagNumber(5)
  set maxState(Slots_SlotState v) {
    setField(5, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasMaxState() => $_has(4);

  @$pb.TagNumber(5)
  void clearMaxState() => clearField(5);

  @$pb.TagNumber(6)
  $core.List<$core.int> get chargeGroups => $_getList(5);
}

class Slots_Slot extends $pb.GeneratedMessage {
  factory Slots_Slot({
    $0.I18N? name,
    $core.bool? published,
    Slots_SlotState? maxState,
    $core.Iterable<$core.int>? chargeGroups,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (published != null) {
      $result.published = published;
    }
    if (maxState != null) {
      $result.maxState = maxState;
    }
    if (chargeGroups != null) {
      $result.chargeGroups.addAll(chargeGroups);
    }
    return $result;
  }

  Slots_Slot._() : super();

  factory Slots_Slot.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory Slots_Slot.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Slots.Slot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'slots'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.bool>(2, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..e<Slots_SlotState>(3, _omitFieldNames ? '' : 'maxState', $pb.PbFieldType.QE,
        protoName: 'maxState',
        defaultOrMaker: Slots_SlotState.PASSIVE,
        valueOf: Slots_SlotState.valueOf,
        enumValues: Slots_SlotState.values)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'chargeGroups', $pb.PbFieldType.P3,
        protoName: 'chargeGroups');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Slots_Slot clone() => Slots_Slot()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Slots_Slot copyWith(void Function(Slots_Slot) updates) =>
      super.copyWith((message) => updates(message as Slots_Slot)) as Slots_Slot;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Slots_Slot create() => Slots_Slot._();

  Slots_Slot createEmptyInstance() => create();

  static $pb.PbList<Slots_Slot> createRepeated() => $pb.PbList<Slots_Slot>();

  @$core.pragma('dart2js:noInline')
  static Slots_Slot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Slots_Slot>(create);
  static Slots_Slot? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);

  @$pb.TagNumber(1)
  set name($0.I18N v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);

  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get published => $_getBF(1);

  @$pb.TagNumber(2)
  set published($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPublished() => $_has(1);

  @$pb.TagNumber(2)
  void clearPublished() => clearField(2);

  @$pb.TagNumber(3)
  Slots_SlotState get maxState => $_getN(2);

  @$pb.TagNumber(3)
  set maxState(Slots_SlotState v) {
    setField(3, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasMaxState() => $_has(2);

  @$pb.TagNumber(3)
  void clearMaxState() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get chargeGroups => $_getList(3);
}

class Slots_ImplantSlot extends $pb.GeneratedMessage {
  factory Slots_ImplantSlot({
    $0.I18N? name,
    $core.bool? published,
    $core.int? slot,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (published != null) {
      $result.published = published;
    }
    if (slot != null) {
      $result.slot = slot;
    }
    return $result;
  }

  Slots_ImplantSlot._() : super();

  factory Slots_ImplantSlot.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory Slots_ImplantSlot.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Slots.ImplantSlot',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'slots'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.bool>(2, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'slot', $pb.PbFieldType.Q3);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Slots_ImplantSlot clone() => Slots_ImplantSlot()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Slots_ImplantSlot copyWith(void Function(Slots_ImplantSlot) updates) =>
      super.copyWith((message) => updates(message as Slots_ImplantSlot)) as Slots_ImplantSlot;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Slots_ImplantSlot create() => Slots_ImplantSlot._();

  Slots_ImplantSlot createEmptyInstance() => create();

  static $pb.PbList<Slots_ImplantSlot> createRepeated() => $pb.PbList<Slots_ImplantSlot>();

  @$core.pragma('dart2js:noInline')
  static Slots_ImplantSlot getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Slots_ImplantSlot>(create);
  static Slots_ImplantSlot? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);

  @$pb.TagNumber(1)
  set name($0.I18N v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);

  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get published => $_getBF(1);

  @$pb.TagNumber(2)
  set published($core.bool v) {
    $_setBool(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasPublished() => $_has(1);

  @$pb.TagNumber(2)
  void clearPublished() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get slot => $_getIZ(2);

  @$pb.TagNumber(3)
  set slot($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasSlot() => $_has(2);

  @$pb.TagNumber(3)
  void clearSlot() => clearField(3);
}

class Slots extends $pb.GeneratedMessage {
  factory Slots({
    $core.Map<$core.int, Slots_HighSlot>? high,
    $core.Map<$core.int, Slots_Slot>? med,
    $core.Map<$core.int, Slots_Slot>? low,
    $core.Map<$core.int, Slots_Slot>? rig,
    $core.Map<$core.int, Slots_Slot>? subsystem,
    $core.Map<$core.int, Slots_ImplantSlot>? implant,
  }) {
    final $result = create();
    if (high != null) {
      $result.high.addAll(high);
    }
    if (med != null) {
      $result.med.addAll(med);
    }
    if (low != null) {
      $result.low.addAll(low);
    }
    if (rig != null) {
      $result.rig.addAll(rig);
    }
    if (subsystem != null) {
      $result.subsystem.addAll(subsystem);
    }
    if (implant != null) {
      $result.implant.addAll(implant);
    }
    return $result;
  }

  Slots._() : super();

  factory Slots.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory Slots.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Slots',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'slots'), createEmptyInstance: create)
    ..m<$core.int, Slots_HighSlot>(1, _omitFieldNames ? '' : 'high',
        entryClassName: 'Slots.HighEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_HighSlot.create,
        valueDefaultOrMaker: Slots_HighSlot.getDefault,
        packageName: const $pb.PackageName('slots'))
    ..m<$core.int, Slots_Slot>(2, _omitFieldNames ? '' : 'med',
        entryClassName: 'Slots.MedEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_Slot.create,
        valueDefaultOrMaker: Slots_Slot.getDefault,
        packageName: const $pb.PackageName('slots'))
    ..m<$core.int, Slots_Slot>(3, _omitFieldNames ? '' : 'low',
        entryClassName: 'Slots.LowEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_Slot.create,
        valueDefaultOrMaker: Slots_Slot.getDefault,
        packageName: const $pb.PackageName('slots'))
    ..m<$core.int, Slots_Slot>(4, _omitFieldNames ? '' : 'rig',
        entryClassName: 'Slots.RigEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_Slot.create,
        valueDefaultOrMaker: Slots_Slot.getDefault,
        packageName: const $pb.PackageName('slots'))
    ..m<$core.int, Slots_Slot>(5, _omitFieldNames ? '' : 'subsystem',
        entryClassName: 'Slots.SubsystemEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_Slot.create,
        valueDefaultOrMaker: Slots_Slot.getDefault,
        packageName: const $pb.PackageName('slots'))
    ..m<$core.int, Slots_ImplantSlot>(6, _omitFieldNames ? '' : 'implant',
        entryClassName: 'Slots.ImplantEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Slots_ImplantSlot.create,
        valueDefaultOrMaker: Slots_ImplantSlot.getDefault,
        packageName: const $pb.PackageName('slots'));

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Slots clone() => Slots()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Slots copyWith(void Function(Slots) updates) =>
      super.copyWith((message) => updates(message as Slots)) as Slots;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Slots create() => Slots._();

  Slots createEmptyInstance() => create();

  static $pb.PbList<Slots> createRepeated() => $pb.PbList<Slots>();

  @$core.pragma('dart2js:noInline')
  static Slots getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Slots>(create);
  static Slots? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Slots_HighSlot> get high => $_getMap(0);

  @$pb.TagNumber(2)
  $core.Map<$core.int, Slots_Slot> get med => $_getMap(1);

  @$pb.TagNumber(3)
  $core.Map<$core.int, Slots_Slot> get low => $_getMap(2);

  @$pb.TagNumber(4)
  $core.Map<$core.int, Slots_Slot> get rig => $_getMap(3);

  @$pb.TagNumber(5)
  $core.Map<$core.int, Slots_Slot> get subsystem => $_getMap(4);

  @$pb.TagNumber(6)
  $core.Map<$core.int, Slots_ImplantSlot> get implant => $_getMap(5);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
