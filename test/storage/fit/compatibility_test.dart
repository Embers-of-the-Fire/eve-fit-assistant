@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;
import "package:riverpod/riverpod.dart";

FitMetadata _fitMeta(String fitId, String checkoutId, String serverId) => FitMetadata(
  fitId: fitId,
  shipTypeId: 1234,
  name: "Test Fit",
  lastModified: 0,
  description: "",
  checkoutRef: CheckoutRef(checkoutId: checkoutId, serverId: serverId),
);

Option<CheckoutRegistryEntry> _active(String serverId) => Some(
  CheckoutRegistryEntry(
    channel: "test-channel",
    serverId: serverId,
    resourceSnapshotHash: "test-snapshot-hash",
    createdAt: "2024-01-01T00:00:00Z",
  ),
);

late String _tempDir;

ProviderContainer _container({
  required String fitId,
  required FitMetadata metadata,
  required Option<CheckoutRegistryEntry> active,
  required String activeCheckoutId,
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

  return ProviderContainer(
    overrides: [
      activeCheckoutProvider.overrideWithValue(active),
      activeCheckoutIdProvider.overrideWithValue(
        activeCheckoutId.isEmpty ? const None() : Some(activeCheckoutId),
      ),
    ],
  );
}

void main() {
  setUp(() {
    _tempDir = Directory.systemTemp.createTempSync("efa_compat_test_").path;
    PathProvider.documentsPath = _tempDir;
    PathProvider.appSupportPath = _tempDir;
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test("returns compatible when active checkout matches fit's checkout", () {
    final container = _container(
      fitId: "fit-a",
      metadata: _fitMeta("fit-a", "checkout-1", "Serenity"),
      active: _active("Serenity"),
      activeCheckoutId: "checkout-1",
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
      active: _active("Serenity"),
      activeCheckoutId: "checkout-2",
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
      active: _active("Tranquility"),
      activeCheckoutId: "checkout-1",
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
      active: _active("Serenity"),
      activeCheckoutId: "checkout-1",
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
      active: _active("Serenity"),
      activeCheckoutId: "checkout-1",
    );
    addTearDown(container.dispose);

    final result = container.read(fitCheckoutCompatibilityProvider("fit-missing"));
    expect(result, isNull);
  });
}
