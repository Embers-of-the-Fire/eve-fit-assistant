import 'package:eve_fit_assistant/pages/create/ship_select.dart';
import 'package:flutter/material.dart';

void startFitCreation(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const ShipSelectPage()),
  );
}
