import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/blob_ident.dart";
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

    test("equality by identHash", () {
      final a = BlobIdent.resource("proto/ships.bin");
      final b = BlobIdent.resource("proto/ships.bin");
      expect(a, b);
    });

    test("different idents unequal", () {
      final ships = BlobIdent.resource("proto/ships.bin");
      final skills = BlobIdent.resource("proto/skills.bin");
      expect(ships, isNot(skills));
    });
  });
}
