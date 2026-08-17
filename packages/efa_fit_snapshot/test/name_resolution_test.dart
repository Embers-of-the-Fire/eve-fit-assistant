import "dart:ui";

import "package:efa_fit_snapshot/src/l10n.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("resolveSnapshotName", () {
    const names = {"en": "Rokh", "zh": "罗克级"};

    test("prefers exact language tag", () {
      expect(resolveSnapshotName(names, const Locale("zh")), "罗克级");
      expect(resolveSnapshotName(names, const Locale("en")), "Rokh");
    });

    test("falls back to language code then en then first", () {
      expect(resolveSnapshotName(names, const Locale("zh", "CN")), "罗克级");
      expect(resolveSnapshotName(names, const Locale("fr")), "Rokh");
      expect(resolveSnapshotName(const {"zh": "罗克级"}, const Locale("fr")), "罗克级");
    });

    test("empty map yields empty string", () {
      expect(resolveSnapshotName(const {}, const Locale("en")), "");
    });
  });
}
