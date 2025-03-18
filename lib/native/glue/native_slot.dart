import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/storage/fit/fit.dart';

extension SlotTypeExt on SlotType {
  FitItemType get fitItemType => FitItemType.fromNative(this);
}

extension SlotInfoExt on SlotInfo {
  bool get isError => this is SlotInfo_Error;

  bool get isWarning => this is SlotInfo_Warning;
}
