import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;
import "package:riverpod/riverpod.dart";

const _testMeta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");

FitMetadata _fitMeta(String fitId, String checkoutId, String serverId) => FitMetadata(
  fitId: fitId,
  shipTypeId: 1234,
  name: "Test Fit",
  lastModified: 0,
  description: "",
  checkoutRef: CheckoutRef(checkoutId: checkoutId, serverId: serverId, metadata: _testMeta),
);

Option<Active> _active(String checkoutId, String serverId) => Some(
  Active(
    schemaVersion: 3,
    checkoutId: checkoutId,
    activatedAt: "2024-01-01T00:00:00Z",
    serverId: serverId,
    metadata: _testMeta,
  ),
);

late String _tempDir;

ProviderContainer _container({
  required String fitId,
  required FitMetadata metadata,
  required Option<Active> active,
}) {
  // Set up the fit registry on disk so FitRegistryManager can read it
  final regPath = p.join(PathProvider.fittingsPath, "registry.json");
  final regDir = Directory(p.dirname(regPath));
  if (!regDir.existsSync()) regDir.createSync(recursive: true);
  File(regPath).writeAsStringSync(
    jsonEncode({
      "fits": {fitId: metadata.toJson()},
    }),
  );

  return ProviderContainer(overrides: [activeCheckoutProvider.overrideWithValue(active)]);
}

void main() {
  setUp(() {
    _tempDir = Directory.systemTemp.createTempSync("efa_compat_test_").path;
    PathProvider.documentsPath = _tempDir;
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test("returns compatible when active checkout matches fit's checkout", () {
    final container = _container(
      fitId: "fit-a",
      metadata: _fitMeta("fit-a", "checkout-1", "Serenity"),
      active: _active("checkout-1", "Serenity"),
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-a"));
    expect(result, isNotNull);
    expect(result!.kind, FitCheckoutCompatibilityKind.compatible);
    expect(result.allowsEditing, isTrue);
  });

  test("returns outdated when same server but different checkout", () {
    final container = _container(
      fitId: "fit-b",
      metadata: _fitMeta("fit-b", "checkout-1", "Serenity"),
      active: _active("checkout-2", "Serenity"),
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-b"));
    expect(result, isNotNull);
    expect(result!.kind, FitCheckoutCompatibilityKind.outdated);
  });

  test("returns incompatible when different server", () {
    final container = _container(
      fitId: "fit-c",
      metadata: _fitMeta("fit-c", "checkout-1", "Serenity"),
      active: _active("checkout-1", "Tranquility"),
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-c"));
    expect(result, isNotNull);
    expect(result!.kind, FitCheckoutCompatibilityKind.incompatible);
  });

  test("returns compatible when fit has empty checkout ID (sentinel)", () {
    final container = _container(
      fitId: "fit-d",
      metadata: _fitMeta("fit-d", "", ""),
      active: _active("checkout-1", "Serenity"),
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-d"));
    expect(result, isNotNull);
    expect(result!.kind, FitCheckoutCompatibilityKind.compatible);
  });

  test("returns null when fit metadata is missing from registry", () {
    final container = _container(
      fitId: "fit-e",
      metadata: _fitMeta("fit-e", "checkout-1", "Serenity"),
      active: _active("checkout-1", "Serenity"),
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-missing"));
    expect(result, isNull);
  });
}
