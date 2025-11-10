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
