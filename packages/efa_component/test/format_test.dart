import "package:efa_component/efa_component.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("NumExt", () {
    test("toStringAsMaxDecimals truncates without rounding loss", () {
      expect(1.23456.toStringAsMaxDecimals(2), "1.23");
      expect(5.0.toStringAsMaxDecimals(1), "5.0");
      expect(12.toStringAsMaxDecimals(3), "12.000");
    });

    test("commaSeparated groups thousands", () {
      expect(1234567.commaSeparated, "1,234,567");
      expect(999.commaSeparated, "999");
    });

    test("moneyFormat keeps two decimals", () {
      expect(1234567.8.moneyFormat, "1,234,567.80");
    });
  });

  group("DurationExt", () {
    test("formats HH:MM:SS", () {
      expect(const Duration(hours: 1, minutes: 2, seconds: 3).format(), "01:02:03");
      expect(const Duration(seconds: 65).format(), "00:01:05");
      expect(const Duration(seconds: -65).format(), "-00:01:05");
    });
  });

  group("resourceUsageColor", () {
    test("steps green/orange/red", () {
      expect(resourceUsageColor(50, 100), Colors.green);
      expect(resourceUsageColor(95, 100), Colors.orange);
      expect(resourceUsageColor(95, 100, warning: false), Colors.green);
      expect(resourceUsageColor(101, 100), Colors.red);
    });
  });
}
