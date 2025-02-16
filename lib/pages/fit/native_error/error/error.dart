library;

import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:flutter/material.dart';

part 'charge_size.dart';
part 'item_num.dart';

Widget renderError(ErrorKey errorKey) => switch (errorKey) {
      ErrorKey_IncompatibleChargeSize(:final expected, :final int actual) =>
        IncompatibleChargeSize(expected: expected, actual: actual),
      ErrorKey_IncompatibleChargeCapacity(:final max, :final actual) =>
        IncompatibleChargeCapacity(max: max, actual: actual),
      ErrorKey_TooMuchTurret(:final expected, :final actual) =>
        TooMuchTurret(expected: expected, actual: actual),
      ErrorKey_TooMuchLauncher(:final expected, :final actual) =>
        TooMuchLauncher(expected: expected, actual: actual),

      // ignore: unreachable_switch_case
      _ => const Text('error'),
    };

const _errorIcon = Icon(Icons.warning_amber, color: Colors.red);
