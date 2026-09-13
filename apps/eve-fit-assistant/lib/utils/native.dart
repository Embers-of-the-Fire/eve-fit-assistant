import "dart:math";

import "package:efa_constant/eve.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;

part "native/algo/capacitor.dart";
part "native/algo/neutralization.dart";

extension NativeItemExt on native.Item {
  double getAttribute(int attrId, [double defaultValue = 0.0]) =>
      attributes[attrId]?.value ?? defaultValue;
}
