import "package:freezed_annotation/freezed_annotation.dart";

part "list_tile_anti_scroll.g.dart";

@JsonEnum(alwaysCreate: true)
enum ListTileAntiScrollLevel {
  @JsonValue("closed")
  closed,
  @JsonValue("weak")
  weak,
  @JsonValue("medium")
  medium,
  @JsonValue("strong")
  strong;

  double get centerRatio => switch (this) {
    ListTileAntiScrollLevel.closed => 1.0,
    ListTileAntiScrollLevel.weak => 0.5,
    ListTileAntiScrollLevel.medium => 1.0 / 3.0,
    ListTileAntiScrollLevel.strong => 0.2,
  };
}
