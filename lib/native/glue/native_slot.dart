import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';

extension SlotTypeExt on SlotType {
  FitItemType get fitItemType {
    switch (this) {
      case SlotType.high:
        return FitItemType.high;
      case SlotType.medium:
        return FitItemType.med;
      case SlotType.low:
        return FitItemType.low;
      case SlotType.rig:
        return FitItemType.rig;
      case SlotType.subsystem:
        return FitItemType.subsystem;
      case SlotType.implant:
        return FitItemType.implant;
      case SlotType.drone:
        return FitItemType.drone;
    }
  }
}

extension SlotInfoExt on SlotInfo {
  bool get isError => this is SlotInfo_Error;

  bool get isWarning => this is SlotInfo_Warning;
}
