import "package:efa_component/efa_component.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";

extension FitItemStateEfaExt on FitItemState {
  EfaItemState toEfa() => switch (this) {
    FitItemState.passive => EfaItemState.passive,
    FitItemState.online => EfaItemState.online,
    FitItemState.active => EfaItemState.active,
    FitItemState.overload => EfaItemState.overload,
  };
}
