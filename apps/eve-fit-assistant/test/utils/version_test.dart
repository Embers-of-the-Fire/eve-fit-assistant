import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("compareVersions", () {
    test("orders plain release triplets", () {
      expect(compareVersions("1.2.3", "1.2.4"), isNegative);
      expect(compareVersions("1.2.4", "1.2.3"), isPositive);
      expect(compareVersions("1.2.3", "1.2.3"), isZero);
    });

    test("prerelease sorts below its release", () {
      expect(compareVersions("1.0.0-beta.1", "1.0.0"), isNegative);
      expect(compareVersions("1.0.0", "1.0.0-beta.2"), isPositive);
    });

    test("prerelease counter compares numerically", () {
      expect(compareVersions("1.0.0-beta.2", "1.0.0-beta.1"), isPositive);
      expect(compareVersions("1.0.0-beta.10", "1.0.0-beta.9"), isPositive);
    });

    test("prerelease labels compare lexically", () {
      expect(compareVersions("1.0.0-rc.1", "1.0.0-beta.2"), isPositive);
      expect(compareVersions("1.0.0-alpha.1", "1.0.0-beta.1"), isNegative);
    });

    test("build metadata is ignored", () {
      expect(compareVersions("1.0.0-beta.2+5000", "1.0.0-beta.2+37"), isZero);
      expect(compareVersions("1.0.0-beta.2+5000", "1.0.0-beta.1+37"), isPositive);
    });

    test("missing segments default to zero", () {
      expect(compareVersions("1.2", "1.2.1"), isNegative);
      expect(compareVersions("1.2", "1.2.0"), isZero);
    });
  });

  group("isAppVersionBelow", () {
    test("prerelease is below the stable release", () {
      expect(isAppVersionBelow("1.0.0-beta.2", "1.0.0"), isTrue);
      expect(isAppVersionBelow("1.0.0", "1.0.0-beta.2"), isFalse);
      expect(isAppVersionBelow("1.0.0-beta.1", "1.0.0-beta.2"), isTrue);
    });

    test("empty versions never count as below", () {
      expect(isAppVersionBelow("", "1.0.0"), isFalse);
      expect(isAppVersionBelow("1.0.0", ""), isFalse);
    });
  });

  group("isBugfixOnlyUpgrade", () {
    group("0.x versions (patch is the bugfix component)", () {
      test("patch bump is bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "0.9.1", remote: "0.9.2"), isTrue);
      });

      test("minor bump is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "0.9.1", remote: "0.10.0"), isFalse);
      });

      test("minor bump with patch reset is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "0.9.9", remote: "0.10.0"), isFalse);
      });

      test("crossing 1.0 is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "0.9.9", remote: "1.0.0"), isFalse);
      });
    });

    group("1.x and later (minor is the bugfix component)", () {
      test("patch bump is bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "1.2.4"), isTrue);
      });

      test("minor bump is bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "1.3.0"), isTrue);
      });

      test("major bump is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "2.0.0"), isFalse);
      });
    });

    group("prerelease handling", () {
      test("adding a prerelease label is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "1.2.4-rc1"), isFalse);
      });

      test("removing a prerelease label is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3-rc1", remote: "1.2.4"), isFalse);
      });

      test("identical prerelease labels keep bugfix classification", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3-rc1", remote: "1.2.4-rc1"), isTrue);
      });
    });

    group("version format tolerance", () {
      test("build metadata is ignored", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3+5", remote: "1.2.4+6"), isTrue);
      });

      test("v prefix is ignored", () {
        expect(isBugfixOnlyUpgrade(installed: "v1.2.3", remote: "v1.3.0"), isTrue);
      });

      test("missing minor/patch segments default to zero", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2", remote: "1.2.1"), isTrue);
      });
    });

    group("non-upgrades", () {
      test("same version is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "1.2.3"), isFalse);
      });

      test("downgrade is not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "1.3.0", remote: "1.2.9"), isFalse);
      });

      test("unparseable versions are not bugfix-only", () {
        expect(isBugfixOnlyUpgrade(installed: "not-a-version", remote: "1.2.4"), isFalse);
        expect(isBugfixOnlyUpgrade(installed: "1.2.3", remote: "not-a-version"), isFalse);
      });
    });
  });
}
