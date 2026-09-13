import "package:eve_fit_assistant/utils/native.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("neutralizationResistanceRate", () {
    test("default attribute (1.0) means no resistance", () {
      expect(neutralizationResistanceRate(1.0), 0.0);
    });

    test("lower multiplier means higher resistance", () {
      expect(neutralizationResistanceRate(0.6), closeTo(0.4, 1e-9));
    });

    test("clamped to 0..1", () {
      expect(neutralizationResistanceRate(1.5), 0.0);
      expect(neutralizationResistanceRate(0.0), 1.0);
    });
  });

  group("neutralizationBreakPeakRate", () {
    test("no resistance returns the raw margin", () {
      expect(
        neutralizationBreakPeakRate(peakDelta: 12.5, energyWarfareResistance: 1.0),
        closeTo(12.5, 1e-9),
      );
    });

    test("resistance scales the required incoming rate up", () {
      expect(
        neutralizationBreakPeakRate(peakDelta: 12.5, energyWarfareResistance: 0.5),
        closeTo(25.0, 1e-9),
      );
    });

    test("full resistance makes the peak unbreakable", () {
      expect(
        neutralizationBreakPeakRate(peakDelta: 12.5, energyWarfareResistance: 0.0),
        double.infinity,
      );
    });

    test("negative margin is clamped to zero", () {
      expect(neutralizationBreakPeakRate(peakDelta: -3, energyWarfareResistance: 1.0), 0.0);
    });
  });

  group("neutralizationClearAmount", () {
    test("no resistance returns the raw capacity", () {
      expect(
        neutralizationClearAmount(capacity: 1875, energyWarfareResistance: 1.0),
        closeTo(1875, 1e-9),
      );
    });

    test("resistance scales the required neutralization up", () {
      expect(
        neutralizationClearAmount(capacity: 1875, energyWarfareResistance: 0.6),
        closeTo(3125, 1e-9),
      );
    });

    test("full resistance makes the capacitor unclearable", () {
      expect(
        neutralizationClearAmount(capacity: 1875, energyWarfareResistance: 0.0),
        double.infinity,
      );
    });
  });
}
