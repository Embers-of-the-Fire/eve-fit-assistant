//
//  Generated code. Do not modify.
//  source: i18n.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class I18N extends $pb.GeneratedMessage {
  factory I18N({
    $core.String? en,
    $core.String? zh,
  }) {
    final $result = create();
    if (en != null) {
      $result.en = en;
    }
    if (zh != null) {
      $result.zh = zh;
    }
    return $result;
  }

  I18N._() : super();

  factory I18N.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory I18N.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'I18N',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'i18n'), createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'en')
    ..aOS(2, _omitFieldNames ? '' : 'zh');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  I18N clone() => I18N()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  I18N copyWith(void Function(I18N) updates) =>
      super.copyWith((message) => updates(message as I18N)) as I18N;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static I18N create() => I18N._();

  I18N createEmptyInstance() => create();

  static $pb.PbList<I18N> createRepeated() => $pb.PbList<I18N>();

  @$core.pragma('dart2js:noInline')
  static I18N getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<I18N>(create);
  static I18N? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get en => $_getSZ(0);

  @$pb.TagNumber(1)
  set en($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasEn() => $_has(0);

  @$pb.TagNumber(1)
  void clearEn() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get zh => $_getSZ(1);

  @$pb.TagNumber(2)
  set zh($core.String v) {
    $_setString(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasZh() => $_has(1);

  @$pb.TagNumber(2)
  void clearZh() => clearField(2);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
