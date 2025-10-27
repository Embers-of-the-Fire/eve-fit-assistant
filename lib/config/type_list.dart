import "package:freezed_annotation/freezed_annotation.dart";

part "type_list.g.dart";

@JsonEnum(alwaysCreate: true)
enum TypeListDisplayVariant {
  @JsonValue("category")
  category,
  @JsonValue("market-group")
  marketGroup,
}
