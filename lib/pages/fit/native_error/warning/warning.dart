library;

import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:flutter/material.dart';

part 'missing_charge.dart';

Widget renderWarning(WarningKey warningKey) => switch (warningKey) {
      WarningKey_MissingCharge() => const MissingCharge(),
      _ => const Text('未知警告'),
    };

const _warningIcon = Icon(Icons.warning_amber, color: Colors.orange);
