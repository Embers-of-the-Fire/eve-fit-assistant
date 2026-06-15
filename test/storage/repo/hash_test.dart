import "dart:convert";
import "dart:typed_data";

import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("RepoHash.hashContent", () {
    test("produces correct SHA-256 hex for known byte sequence", () {
      final bytes = utf8.encode("hello");
      expect(
        RepoHash.hashContent(Uint8List.fromList(bytes)),
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
      );
    });

    test("produces same result as hashBytes", () {
      final bytes = Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
      expect(RepoHash.hashContent(bytes), RepoHash.hashBytes(bytes));
    });
  });

  group("RepoHash.canonicalizePath", () {
    test("returns forward-slashed path unchanged", () {
      expect(RepoHash.canonicalizePath("data/foo/bar.json"), "data/foo/bar.json");
    });

    test("converts backslashes to forward slashes", () {
      expect(RepoHash.canonicalizePath(r"data\foo\bar.json"), "data/foo/bar.json");
    });

    test("strips trailing slash", () {
      expect(RepoHash.canonicalizePath("data/foo/"), "data/foo");
    });

    test("strips . segments", () {
      expect(RepoHash.canonicalizePath("data/./foo/bar.json"), "data/foo/bar.json");
    });

    test("strips .. segments", () {
      expect(RepoHash.canonicalizePath("data/foo/baz/../bar.json"), "data/foo/bar.json");
    });

    test("strips both . and .. segments", () {
      expect(RepoHash.canonicalizePath("./data/foo/../bar.json"), "data/bar.json");
    });

    test("throws on .. going above root", () {
      expect(() => RepoHash.canonicalizePath("../data/foo.json"), throwsA(isA<ArgumentError>()));
    });

    test("returns empty string for root-only path", () {
      expect(RepoHash.canonicalizePath("/"), "");
    });

    test("returns empty string for .", () {
      expect(RepoHash.canonicalizePath("."), "");
    });

    test("throws on .. going above root from root", () {
      expect(() => RepoHash.canonicalizePath(".."), throwsA(isA<ArgumentError>()));
    });

    test("handles multiple consecutive slashes", () {
      expect(RepoHash.canonicalizePath("data//foo///bar.json"), "data/foo/bar.json");
    });

    test("handles mixed separators", () {
      expect(RepoHash.canonicalizePath(r"data\foo/bar.json"), "data/foo/bar.json");
    });
  });

  group("RepoHash.hashPath", () {
    test("produces 64-char hex digest", () {
      expect(RepoHash.hashPath("data/foo/bar.json"), hasLength(64));
    });

    test("normalizes before hashing", () {
      expect(RepoHash.hashPath(r"data\foo/bar.json"), RepoHash.hashPath("data/foo/bar.json"));
    });

    test("equivalent to hashCanonicalPath", () {
      expect(
        RepoHash.hashPath("data/foo/bar.json"),
        RepoHash.hashCanonicalPath("data/foo/bar.json"),
      );
    });
  });

  group("RepoHash.hashCheckout", () {
    test("returns 64-char hex digest for empty entries", () {
      final hash = RepoHash.hashCheckout([]);
      expect(hash, hasLength(64));
      expect(hash, isNot(RepoHash.hashString("")));
    });

    test("produces deterministic output for same input", () {
      final entries = [
        (pathHash: "aaa", contentHash: "111"),
        (pathHash: "bbb", contentHash: "222"),
      ];
      final a = RepoHash.hashCheckout(entries);
      final b = RepoHash.hashCheckout(entries);
      expect(a, b);
    });

    test("produces different output for different content hashes", () {
      final a = RepoHash.hashCheckout([(pathHash: "aaa", contentHash: "000")]);
      final b = RepoHash.hashCheckout([(pathHash: "aaa", contentHash: "111")]);
      expect(a, isNot(b));
    });

    test("sorts entries by pathHash", () {
      final a = RepoHash.hashCheckout([
        (pathHash: "bbb", contentHash: "222"),
        (pathHash: "aaa", contentHash: "111"),
      ]);
      final b = RepoHash.hashCheckout([
        (pathHash: "aaa", contentHash: "111"),
        (pathHash: "bbb", contentHash: "222"),
      ]);
      expect(a, b);
    });

    test("produces precomputed expected hash for known set", () {
      // Build the expected string and hash it ourselves:
      // efa:checkout:v2\naaa 111\nbbb 222\n
      final entries = [
        (pathHash: "aaa", contentHash: "111"),
        (pathHash: "bbb", contentHash: "222"),
      ];
      final expectedString = "efa:checkout:v2\naaa 111\nbbb 222\n";
      final expected = RepoHash.hashString(expectedString);
      expect(RepoHash.hashCheckout(entries), expected);
    });

    test("hash changes when a file entry is added", () {
      final a = RepoHash.hashCheckout([(pathHash: "aaa", contentHash: "000")]);
      final b = RepoHash.hashCheckout([
        (pathHash: "aaa", contentHash: "000"),
        (pathHash: "bbb", contentHash: "111"),
      ]);
      expect(a, isNot(b));
    });
  });

  group("RepoHash.hashString", () {
    test("produces correct SHA-256 hex for known input", () {
      expect(
        RepoHash.hashString("hello"),
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824",
      );
    });

    test("produces correct SHA-256 hex for empty string", () {
      expect(
        RepoHash.hashString(""),
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
      );
    });

    test("output is always 64 hex characters", () {
      expect(RepoHash.hashString("data/foo/bar.json"), hasLength(64));
    });
  });

  group("RepoHash.hashBytes", () {
    test("produces same result as hashString for same content", () {
      final bytes = utf8.encode("hello");
      expect(RepoHash.hashBytes(Uint8List.fromList(bytes)), RepoHash.hashString("hello"));
    });
  });

  group("RepoHash.hashCanonicalPath", () {
    test("normalizes backslashes to forward slashes", () {
      final unix = RepoHash.hashCanonicalPath("data/foo/bar.json");
      final windows = RepoHash.hashCanonicalPath("data\\foo\\bar.json");
      expect(unix, windows);
    });

    test("strips . segments", () {
      final a = RepoHash.hashCanonicalPath("data/./foo/bar.json");
      final b = RepoHash.hashCanonicalPath("data/foo/bar.json");
      expect(a, b);
    });

    test("strips .. segments", () {
      final a = RepoHash.hashCanonicalPath("data/foo/baz/../bar.json");
      final b = RepoHash.hashCanonicalPath("data/foo/bar.json");
      expect(a, b);
    });

    test("strips both . and .. segments", () {
      final a = RepoHash.hashCanonicalPath("./data/foo/../bar.json");
      final b = RepoHash.hashCanonicalPath("data/bar.json");
      expect(a, b);
    });

    test("handles root-relative path", () {
      final hash = RepoHash.hashCanonicalPath("/data/foo/bar.json");
      expect(hash, hasLength(64));
      expect(
        RepoHash.hashCanonicalPath("/data/foo/bar.json"),
        RepoHash.hashCanonicalPath("data/foo/bar.json"),
      );
    });

    test("output is 64 hex characters", () {
      expect(RepoHash.hashCanonicalPath("data/foo/bar.json"), hasLength(64));
    });
  });

  group("RepoHash.hashFilePath", () {
    test("is equivalent to hashCanonicalPath", () {
      final a = RepoHash.hashCanonicalPath("data/foo/bar.json");
      final b = RepoHash.hashFilePath("data/foo/bar.json");
      expect(a, b);
    });

    test("normalizes Windows-style paths like hashCanonicalPath", () {
      final a = RepoHash.hashCanonicalPath("data\\foo\\bar.json");
      final b = RepoHash.hashFilePath("data\\foo\\bar.json");
      expect(a, b);
    });
  });
}
