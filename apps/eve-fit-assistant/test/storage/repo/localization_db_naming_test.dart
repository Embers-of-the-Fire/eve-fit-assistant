import "package:eve_fit_assistant/storage/repo/checkout_db.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("localization OPFS naming helpers", () {
    test("localizationDbNameForHash embeds the content hash", () {
      expect(localizationDbNameForHash("deadbeef"), "localization_deadbeef");
    });

    test("localizationDbFilePath nests the database file under the OPFS root", () {
      expect(
        localizationDbFilePath("localization_deadbeef"),
        "$kLocalizationDbOpfsRoot/localization_deadbeef/database",
      );
    });

    test("isStaleLocalizationDbDir keeps only other localization_* directories", () {
      expect(isStaleLocalizationDbDir("localization_old", keepName: "localization_new"), isTrue);
      expect(isStaleLocalizationDbDir("localization_new", keepName: "localization_new"), isFalse);
      expect(isStaleLocalizationDbDir("other_db", keepName: "localization_new"), isFalse);
      expect(isStaleLocalizationDbDir("localization_", keepName: "localization_new"), isTrue);
    });
  });

  group("per-locale localization specs", () {
    test("resource id derives from the generated pattern", () {
      expect(localeLocalizationDbResourceId("zh"), "resource://localization/locales/zh.db");
    });

    test("spec pins schema version 2 and a locales_<locale> prefix", () {
      final spec = localeLocalizationDbSpec("zh");
      expect(spec.supportedSchemaVersion, "2");
      expect(spec.dbNamePrefix, "locales_zh");
    });

    test("per-locale names embed the content hash", () {
      expect(localeLocalizationDbNameForHash("zh", "deadbeef"), "locales_zh_deadbeef");
    });

    test("per-locale prefix is disjoint from the legacy prune sweep", () {
      // Stale-dir pruning matches `startsWith("<prefix>_")`: the legacy sweep
      // must never match per-locale directories, and vice versa.
      final perLocaleName = localeLocalizationDbNameForHash("zh", "deadbeef");
      expect(
        isStaleCheckoutDbDir(
          kLocalizationDbSpec.dbNamePrefix,
          perLocaleName,
          keepName: "localization_new",
        ),
        isFalse,
      );
      expect(
        isStaleCheckoutDbDir(
          localeLocalizationDbSpec("zh").dbNamePrefix,
          localizationDbNameForHash("deadbeef"),
          keepName: perLocaleName,
        ),
        isFalse,
      );
    });

    test("per-locale sweep prunes only same-locale directories", () {
      final prefix = localeLocalizationDbSpec("zh").dbNamePrefix;
      expect(isStaleCheckoutDbDir(prefix, "locales_zh_old", keepName: "locales_zh_new"), isTrue);
      expect(isStaleCheckoutDbDir(prefix, "locales_zh_new", keepName: "locales_zh_new"), isFalse);
      // Another locale's directories are not this locale's sweep.
      expect(isStaleCheckoutDbDir(prefix, "locales_en_old", keepName: "locales_zh_new"), isFalse);
    });
  });
}
