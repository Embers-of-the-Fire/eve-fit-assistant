import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  setUpAll(() {
    // Initialize PathProvider with test values
    PathProvider.documentsPath = "/test/docs";
    PathProvider.tempPath = "/test/tmp";
    PathProvider.appSupportPath = "/test/support";
    PathProvider.cachesPath = "/test/cache";
  });

  group("blobPath", () {
    test("constructs path with first 2 chars of ident_hash", () {
      const identHash = "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
      const contentHash = "1111111111111111111111111111111100000000000000000000000000000000";
      final path = RepoPaths.blobPath(identHash, contentHash);
      expect(path, contains("blobs/ab/"));
      expect(path, contains(identHash));
      expect(path, contains(contentHash));
    });

    test("throws on short ident_hash", () {
      expect(() => RepoPaths.blobPath("a", "c" * 64), throwsA(isA<ArgumentError>()));
    });
  });

  group("blobIdentDir", () {
    test("returns directory containing all versions of an ident", () {
      const identHash = "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890";
      final dir = RepoPaths.blobIdentDir(identHash);
      expect(dir, contains("blobs/ab/"));
      expect(dir, contains(identHash));
    });
  });

  group("resource snapshot paths", () {
    test("snapshot path includes hash", () {
      final hash = "a" * 64;
      expect(RepoPaths.resourceSnapshotPath(hash), contains(hash));
      expect(RepoPaths.resourceSnapshotPath(hash), contains("resources/"));
    });

    test("metadata and proto paths are under snapshot", () {
      final hash = "a" * 64;
      final meta = RepoPaths.resourceSnapshotMetaPath(hash);
      final proto = RepoPaths.resourceIndexPath(hash);
      expect(meta, endsWith("metadata.json"));
      expect(proto, endsWith("resources.pb2"));
    });
  });

  group("channel paths", () {
    test("registry path", () {
      expect(RepoPaths.channelRegistryPath, contains("channels/channels.json"));
    });

    test("head meta path by channel name", () {
      final path = RepoPaths.channelHeadMetaPath("testing");
      expect(path, contains("channels/testing/metadata.json"));
    });

    test("server index path by channel name", () {
      final path = RepoPaths.channelServerIndexPath("testing");
      expect(path, contains("channels/testing/server.pb2"));
    });

    test("resources path by channel name", () {
      final path = RepoPaths.channelResourcesPath("testing");
      expect(path, contains("channels/testing/resources.pb2"));
    });

    test("releases path by channel name", () {
      final path = RepoPaths.channelReleasesPath("testing");
      expect(path, contains("channels/testing/releases.pb2"));
    });
  });

  group("checkout paths", () {
    test("registry path", () {
      expect(RepoPaths.checkoutRegistryPath, contains("checkouts/checkouts.json"));
    });

    test("meta path by checkout id", () {
      final path = RepoPaths.checkoutMetaPath("uuid-1234");
      expect(path, contains("checkouts/uuid-1234/metadata.json"));
    });

    test("reflog path by checkout id", () {
      final path = RepoPaths.checkoutReflogPath("uuid-1234");
      expect(path, contains("checkouts/uuid-1234/reflog.pb2"));
    });
  });

  group("schema version", () {
    test("schema version path", () {
      expect(RepoPaths.schemaVersionPath, endsWith("schema_version.json"));
    });
  });
}
