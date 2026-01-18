import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";

extension ProtobufSlotStateExt on Slots_SlotState {
  FitItemState get dartImpl => switch (this) {
    Slots_SlotState.PASSIVE => FitItemState.passive,
    Slots_SlotState.ACTIVE => FitItemState.active,
    Slots_SlotState.ONLINE => FitItemState.online,
    Slots_SlotState.OVERLOAD => FitItemState.overload,
    _ => FitItemState.passive,
  };
}

extension FitItemStateExt on FitItemState {
  FitItemState get limitToActive => switch (this) {
    FitItemState.overload => FitItemState.active,
    _ => this,
  };

  FitItemState toggle(FitItemState max) {
    final currNum = index;
    final maxNum = max.index;

    if (currNum < maxNum) {
      return FitItemState.values[currNum + 1];
    }

    return FitItemState.passive;
  }

  FitItemState toggleDrone() {
    switch (this) {
      case FitItemState.passive:
        return FitItemState.active;
      case FitItemState.active:
      case FitItemState.online:
      case FitItemState.overload:
        return FitItemState.passive;
    }
  }
}
