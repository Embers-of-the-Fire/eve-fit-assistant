import "package:eve_fit_assistant/data/proto/manual.pb.dart" as pb;
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:flutter_test/flutter_test.dart";

pb.ManualRegistry _buildRegistry() {
  final createFit = pb.ManualDoc(
    id: "getting-started/create-first-fit",
    order: 10,
    localizations: [
      MapEntry(
        "zh",
        pb.ManualDocLocalization(
          title: "创建你的第一个配置",
          summary: "本章节介绍如何从零开始创建一个新的舰船配置。",
          contentFile: "aaa.md",
        ),
      ),
      MapEntry(
        "en",
        pb.ManualDocLocalization(
          title: "Creating Your First Fit",
          summary: "This chapter walks you through creating a new ship fit from scratch.",
          contentFile: "bbb.md",
        ),
      ),
    ],
  );

  final browseShips = pb.ManualDoc(
    id: "getting-started/browse-ships",
    order: 20,
    localizations: [
      MapEntry(
        "en",
        pb.ManualDocLocalization(
          title: "Browsing Ships",
          summary: "Learn how to find and filter ships in the ship browser.",
          contentFile: "ccc.md",
        ),
      ),
    ],
  );

  final modules = pb.ManualDoc(
    id: "fitting/advanced/modules",
    order: 10,
    localizations: [
      MapEntry(
        "en",
        pb.ManualDocLocalization(
          title: "Modules and Slots",
          summary: "Explains the purpose of high, mid, low, and rig slots.",
          contentFile: "ddd.md",
        ),
      ),
    ],
  );

  return pb.ManualRegistry(
    schemaVersion: 1,
    folders: [
      pb.ManualFolder(
        id: "getting-started",
        order: 10,
        name: [const MapEntry("zh", "新手上路"), const MapEntry("en", "Getting Started")],
        docs: [createFit, browseShips],
      ),
      pb.ManualFolder(
        id: "fitting",
        order: 20,
        name: [const MapEntry("zh", "配装"), const MapEntry("en", "Fitting")],
        folders: [
          pb.ManualFolder(
            id: "fitting/advanced",
            order: 5,
            name: [const MapEntry("en", "Advanced")],
            docs: [modules],
          ),
        ],
      ),
    ],
  );
}

void main() {
  group("ManualRepository.convertRegistry", () {
    test("decodes a serialized registry into the manual tree", () {
      final bytes = _buildRegistry().writeToBuffer();
      final registry = pb.ManualRegistry.fromBuffer(bytes);

      final root = ManualRepository.convertRegistry(registry);

      expect(root.id, isEmpty);
      expect(root.folders, hasLength(2));
      expect(root.folders[0].id, "getting-started");
      expect(root.folders[0].names, {"zh": "新手上路", "en": "Getting Started"});
      expect(root.folders[0].docs, hasLength(2));
      expect(root.folders[1].id, "fitting");
      expect(root.folders[1].folders.single.id, "fitting/advanced");
      expect(root.folders[1].folders.single.docs.single.id, "fitting/advanced/modules");
    });

    test("doc localizations carry title, summary, and content file", () {
      final root = ManualRepository.convertRegistry(_buildRegistry());
      final doc = root.findDoc("getting-started/create-first-fit")!;

      expect(doc.order, 10);
      expect(doc.localizations["zh"]!.title, "创建你的第一个配置");
      expect(doc.localizations["en"]!.contentFile, "bbb.md");
    });
  });

  group("ManualDocEntry.resolveLocalization", () {
    final doc = ManualRepository.convertRegistry(
      _buildRegistry(),
    ).findDoc("getting-started/create-first-fit")!;

    test("exact match wins", () {
      final resolved = doc.resolveLocalization("zh")!;
      expect(resolved.localeCode, "zh");
      expect(resolved.data.title, "创建你的第一个配置");
    });

    test("language prefix match for region codes", () {
      final resolved = doc.resolveLocalization("zh-CN")!;
      expect(resolved.localeCode, "zh");
    });

    test("falls back to en when locale is absent", () {
      final resolved = doc.resolveLocalization("fr")!;
      expect(resolved.localeCode, "en");
    });

    test("falls back to first available when en is absent", () {
      const entry = ManualDocEntry(
        id: "x",
        order: 0,
        localizations: {"zh": ManualDocLocalization(title: "t", summary: "s", contentFile: "f.md")},
      );
      final resolved = entry.resolveLocalization("fr")!;
      expect(resolved.localeCode, "zh");
    });

    test("returns null for empty localizations", () {
      const entry = ManualDocEntry(id: "x", order: 0, localizations: {});
      expect(entry.resolveLocalization("en"), isNull);
    });
  });

  group("ManualFolderEntry", () {
    final root = ManualRepository.convertRegistry(_buildRegistry());

    test("resolveName follows the same fallback chain", () {
      expect(root.folders[0].resolveName("zh"), "新手上路");
      expect(root.folders[0].resolveName("de"), "Getting Started");
      expect(root.folders[1].folders.single.resolveName("zh"), "Advanced");
    });

    test("allDocs traverses depth-first in tree order", () {
      expect(root.allDocs.map((d) => d.id).toList(), [
        "getting-started/create-first-fit",
        "getting-started/browse-ships",
        "fitting/advanced/modules",
      ]);
    });

    test("findDoc returns null for unknown ids", () {
      expect(root.findDoc("nope"), isNull);
    });
  });

  group("resolveManualPath", () {
    final root = ManualRepository.convertRegistry(_buildRegistry());

    test("empty path resolves to the root folder", () {
      final resolution = resolveManualPath(root, "");
      expect(resolution, isA<ManualFolderResolution>());
      final folder = (resolution as ManualFolderResolution).folder;
      expect(folder.id, isEmpty);
      expect(folder.folders, hasLength(2));
    });

    test("top-level folder path", () {
      final resolution = resolveManualPath(root, "fitting");
      expect(resolution, isA<ManualFolderResolution>());
      final folder = (resolution as ManualFolderResolution);
      expect(folder.folder.id, "fitting");
      expect(folder.ancestors, isEmpty);
    });

    test("nested folder path collects ancestors", () {
      final resolution = resolveManualPath(root, "fitting/advanced");
      expect(resolution, isA<ManualFolderResolution>());
      final folder = (resolution as ManualFolderResolution);
      expect(folder.folder.id, "fitting/advanced");
      expect(folder.ancestors.map((f) => f.id), ["fitting"]);
    });

    test("doc path resolves to the doc with its folder chain", () {
      final resolution = resolveManualPath(root, "fitting/advanced/modules");
      expect(resolution, isA<ManualDocResolution>());
      final doc = (resolution as ManualDocResolution);
      expect(doc.doc.id, "fitting/advanced/modules");
      expect(doc.ancestors.map((f) => f.id), ["fitting", "fitting/advanced"]);
    });

    test("doc id under a top-level folder", () {
      final resolution = resolveManualPath(root, "getting-started/browse-ships");
      expect(resolution, isA<ManualDocResolution>());
      final doc = (resolution as ManualDocResolution);
      expect(doc.ancestors.map((f) => f.id), ["getting-started"]);
    });

    test("unknown paths do not resolve", () {
      expect(resolveManualPath(root, "nope"), isA<ManualPathNotFound>());
      expect(resolveManualPath(root, "fitting/nope"), isA<ManualPathNotFound>());
      expect(resolveManualPath(root, "fitting/advanced/modules/extra"), isA<ManualPathNotFound>());
    });

    test("doc path used as an intermediate segment does not resolve", () {
      expect(
        resolveManualPath(root, "getting-started/browse-ships/nested"),
        isA<ManualPathNotFound>(),
      );
    });
  });
}
