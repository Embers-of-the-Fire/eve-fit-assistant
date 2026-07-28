import "package:freezed_annotation/freezed_annotation.dart";

part "force_column.g.dart";

@JsonEnum(alwaysCreate: true)
enum ForceColumnSelection {
  @JsonValue("disabled")
  disabled,
  @JsonValue("force-1")
  force1,
  @JsonValue("force-2")
  force2,
  @JsonValue("force-3")
  force3;

  String get label => switch (this) {
    ForceColumnSelection.disabled => "Disabled",
    ForceColumnSelection.force1 => "Force 1",
    ForceColumnSelection.force2 => "Force 2",
    ForceColumnSelection.force3 => "Force 3",
  };
}
