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
}
