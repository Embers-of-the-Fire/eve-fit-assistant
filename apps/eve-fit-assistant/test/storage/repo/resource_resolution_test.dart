@TestOn("vm")
library;

import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/resource_resolution.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";

const _ctx = ResourceResolutionContext(locale: "zh");

ResourceIndex_Entry _entry(String resourceId) => ResourceIndex_Entry()
  ..resourceId = resourceId
  ..contentHash = "aa" * 32
  ..size = Int64(1);

ResourceIndex _index(Iterable<String> resourceIds) {
  final index = ResourceIndex()
    ..schemaVersion = 1
    ..formatVersion = 2;
  for (final id in resourceIds) {
    index.entries.add(_entry(id));
  }
  return index;
}

ResourceResolution _resolve(String id, {List<String> indexIds = const [], String locale = "zh"}) =>
    resolveResource(
      _index([id, ...indexIds]),
      _entry(id),
      ResourceResolutionContext(locale: locale),
    );

void main() {
  group("R1: legacy combined localization db", () {
    test("excluded when the index provides per-locale replacements", () {
      expect(
        _resolve(
          "resource://localization/localization.db",
          indexIds: ["resource://localization/locales/zh.db"],
        ),
        ResourceResolution.excluded,
      );
    });

    test("eager against an old snapshot without per-locale dbs", () {
      expect(_resolve("resource://localization/localization.db"), ResourceResolution.eager);
    });
  });

  group("R2: active locale per-locale db", () {
    test("eager for the context locale", () {
      expect(_resolve("resource://localization/locales/zh.db"), ResourceResolution.eager);
    });

    test("follows the context locale", () {
      expect(
        _resolve("resource://localization/locales/en.db", locale: "en"),
        ResourceResolution.eager,
      );
    });

    test("evaluates before the R3 prefix rule", () {
      // R2 must win over R3 for the active locale.
      expect(_resolve("resource://localization/locales/zh.db"), ResourceResolution.eager);
    });
  });

  group("R3: other per-locale dbs", () {
    test("lazy for non-active locales", () {
      expect(_resolve("resource://localization/locales/en.db"), ResourceResolution.lazy);
    });
  });

  group("R4: static images", () {
    test("lazy for icons and graphics", () {
      expect(_resolve("resource://static/images/icons/1.png"), ResourceResolution.lazy);
      expect(_resolve("resource://static/images/graphics/2_bp.png"), ResourceResolution.lazy);
    });
  });

  group("R5: default", () {
    test("unknown ids fail closed to eager", () {
      expect(_resolve("resource://static/collection.pb2"), ResourceResolution.eager);
      expect(_resolve("resource://agent/agent_resource.db"), ResourceResolution.eager);
      expect(_resolve("resource://future/unknown.blob"), ResourceResolution.eager);
    });
  });

  group("rule ordering and first match", () {
    test("R1 exact match does not fall through to R3", () {
      // The legacy id is not under the locales prefix, but pin ordering by
      // checking the legacy id still hits R1 with per-locale entries present.
      final index = _index([
        "resource://localization/localization.db",
        "resource://localization/locales/en.db",
      ]);
      expect(
        resolveResource(index, _entry("resource://localization/localization.db"), _ctx),
        ResourceResolution.excluded,
      );
    });

    test("R1 `when` reads the index, not the entry", () {
      // The legacy db stays eager when the locales prefix only appears in an
      // unrelated snapshot: here the index contains no locales entry at all.
      final index = _index(["resource://localization/localization.db"]);
      expect(
        resolveResource(index, _entry("resource://localization/localization.db"), _ctx),
        ResourceResolution.eager,
      );
    });

    test("context substitution only affects the exact active-locale id", () {
      // A db whose name merely contains the locale string still hits R3.
      expect(_resolve("resource://localization/locales/zh-tw.db"), ResourceResolution.lazy);
    });
  });

  test("RRS version is 1", () {
    expect(kResourceResolutionSchemaVersion, 1);
  });
}
