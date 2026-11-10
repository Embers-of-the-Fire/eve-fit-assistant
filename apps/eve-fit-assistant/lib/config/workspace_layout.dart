import "package:freezed_annotation/freezed_annotation.dart";

part "workspace_layout.g.dart";

@JsonEnum(alwaysCreate: true)
enum WorkspaceTileStyle {
  @JsonValue("automatic")
  automatic,
  @JsonValue("square")
  square,
  @JsonValue("compact")
  compact,
}

@JsonEnum(alwaysCreate: true)
enum WorkspaceColumnMode {
  @JsonValue("automatic")
  automatic,
  @JsonValue("force-list")
  forceList,
  @JsonValue("force-two-columns")
  forceTwoColumns,
}
