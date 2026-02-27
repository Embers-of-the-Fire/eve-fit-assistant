// This is a generated file - do not edit.
//
// Generated from i18n.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class I18N extends $pb.GeneratedMessage {
  factory I18N({
    $core.String? en,
    $core.String? zh,
  }) {
    final result = create();
    if (en != null) result.en = en;
    if (zh != null) result.zh = zh;
    return result;
  }

  I18N._();

  factory I18N.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory I18N.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'I18N',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'i18n'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'en')
    ..aOS(2, _omitFieldNames ? '' : 'zh');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  I18N clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  I18N copyWith(void Function(I18N) updates) =>
      super.copyWith((message) => updates(message as I18N)) as I18N;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static I18N create() => I18N._();
  @$core.override
  I18N createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static I18N getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<I18N>(create);
  static I18N? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get en => $_getSZ(0);
  @$pb.TagNumber(1)
  set en($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEn() => $_has(0);
  @$pb.TagNumber(1)
  void clearEn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get zh => $_getSZ(1);
  @$pb.TagNumber(2)
  set zh($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasZh() => $_has(1);
  @$pb.TagNumber(2)
  void clearZh() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
