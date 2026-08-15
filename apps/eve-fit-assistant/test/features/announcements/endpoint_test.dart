import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("RemoteContentEndpoint V2 announcement URIs", () {
    final origin = Uri.parse("https://cdn.example.com/");
    final endpoint = RemoteContentEndpoint(originUri: origin, channel: "stable");

    // ── catalog URI ──────────────────────────────────────────────────────────

    test("announcementV2CatalogUri resolves correctly", () {
      final uri = endpoint.announcementV2CatalogUri;
      expect(uri.toString(), "https://cdn.example.com/efa/v2/announcements/catalog.json");
    });

    // ── active page URI ──────────────────────────────────────────────────────

    test("announcementV2ActivePageUri resolves correctly", () {
      final uri = endpoint.announcementV2ActivePageUri;
      expect(uri.toString(), "https://cdn.example.com/efa/v2/announcements/active.json");
    });

    // ── page URI ─────────────────────────────────────────────────────────────

    test("announcementV2PageUri resolves correctly", () {
      final uri = endpoint.announcementV2PageUri("a1b2c3d4-e5f6-7890-abcd-ef1234567890");
      expect(
        uri.toString(),
        "https://cdn.example.com/efa/v2/announcements/pages/a1b2c3d4-"
        "e5f6-7890-abcd-ef1234567890.json",
      );
    });

    // ── body URI ─────────────────────────────────────────────────────────────

    test("announcementV2BodyUri resolves correctly", () {
      const hash = "a1b2c3d4e5f6789012345678901234567890abcd12345678901234567890abcdef";
      final uri = endpoint.announcementV2BodyUri(hash);
      expect(
        uri.toString(),
        "https://cdn.example.com/efa/v2/announcements/documents/"
        "a1b2c3d4e5f6789012345678901234567890abcd12345678901234567890abcdef.md",
      );
    });

    // ── path traversal rejection ─────────────────────────────────────────────

    test("announcementV2PageUri rejects path traversal", () {
      expect(
        () => endpoint.announcementV2PageUri("../evil"),
        throwsA(isA<RemoteContentException>()),
      );
    });

    test("announcementV2BodyUri rejects path traversal", () {
      expect(
        () => endpoint.announcementV2BodyUri("../".padRight(64, "a")),
        throwsA(isA<RemoteContentException>()),
      );
    });

    // ── origin with trailing slash ───────────────────────────────────────────

    test("works with origin that has a trailing slash", () {
      final ep = RemoteContentEndpoint(
        originUri: Uri.parse("https://cdn.example.com/"),
        channel: "beta",
      );
      final uri = ep.announcementV2CatalogUri;
      expect(uri.toString(), "https://cdn.example.com/efa/v2/announcements/catalog.json");
    });

    // ── origin without trailing slash ────────────────────────────────────────

    test("works with origin that lacks a trailing slash", () {
      final ep = RemoteContentEndpoint(
        originUri: Uri.parse("https://cdn.example.com"),
        channel: "beta",
      );
      final uri = ep.announcementV2CatalogUri;
      expect(uri.toString(), "https://cdn.example.com/efa/v2/announcements/catalog.json");
    });
  });
}
