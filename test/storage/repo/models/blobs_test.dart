import "package:eve_fit_assistant/storage/repo/models/blob_ident.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("BlobIdent", () {
    test("resource ident produces expected URI format", () {
      final ident = BlobIdent.resource("proto/ships.bin");
      expect(ident.uri, "resource://proto/ships.bin");
      expect(ident.identHash.length, 64);
    });

    test("resource ident hash matches manual computation", () {
      final ident = BlobIdent.resource("proto/ships.bin");
      final expectedHash = RepoHash.hashIdent("resource://proto/ships.bin");
      expect(ident.identHash, expectedHash);
    });

    test("release ident produces expected URI format", () {
      final ident = BlobIdent.release("android", "2.0.0", "app.apk");
      expect(ident.uri, "release://android/2.0.0/app.apk");
      expect(ident.identHash.length, 64);
    });

    test("release ident hash matches manual computation", () {
      final ident = BlobIdent.release("android", "2.0.0", "app.apk");
      final expectedHash = RepoHash.hashIdent("release://android/2.0.0/app.apk");
      expect(ident.identHash, expectedHash);
    });

    test("equality by identHash", () {
      final a = BlobIdent.resource("proto/ships.bin");
      final b = BlobIdent.resource("proto/ships.bin");
      expect(a, b);
    });

    test("different types unequal", () {
      final resource = BlobIdent.resource("proto/ships.bin");
      final release = BlobIdent.release("android", "2.0.0", "app.apk");
      expect(resource, isNot(release));
    });
  });
}
