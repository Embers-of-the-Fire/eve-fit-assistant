@TestOn("vm")
library;

import "dart:convert";
import "dart:io";

import "package:archive/archive.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/fit_link/codec.dart";
import "package:eve_fit_assistant/features/fit_link/fit_link_uri.dart";
import "package:eve_fit_assistant/features/fit_link/importer.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

class _FakeFitManager extends FitManager {
  final List<FitStorage> imported = [];

  @override
  Future<DateTime> build() async => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<FitMetadata> importFit(FitStorage importedFit) async {
    imported.add(importedFit);
    return importedFit.metadata.copyWith(fitId: "imported-id");
  }
}

final _refCaptureProvider = Provider<Ref>((Ref ref) => ref);

FitStorage _makeFit() => const FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: "Test Fit",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 12017,
    characterId: "predefined_all_5",
    damageProfile: FitDamageProfile(em: 0.25, explosive: 0.25, kinetic: 0.25, thermal: 0.25),
    slots: FitStorageSlots(
      high: IList.empty(),
      medium: IList.empty(),
      low: IList.empty(),
      rig: IList.empty(),
      subsystem: IList.empty(),
      service: IList.empty(),
      tacticalMode: None(),
    ),
    drones: IList.empty(),
    fighters: IList.empty(),
    implants: IList.empty(),
    boosters: IList.empty(),
  ),
  dynamicRegistry: FitDynamicRegistry(dynamicItems: IMap.empty()),
);

void main() {
  late _FakeFitManager fitManager;
  late ProviderContainer container;
  late FitLinkImporter importer;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_fit_link_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    fitManager = _FakeFitManager();
    container = ProviderContainer.test(
      overrides: [fitManagerProvider.overrideWith(() => fitManager)],
    );
    importer = FitLinkImporter(container.read(_refCaptureProvider));
  });

  test("imports a valid link exactly once", () async {
    final fit = _makeFit();
    final uri = Uri.parse(
      "https://share.platform.efa-tech.dev/fit/raw?payload=${encodeFitLinkPayload(fit)}",
    );

    final result = await importer.import(uri);

    expect(result.fitId, "imported-id");
    expect(fitManager.imported, hasLength(1));
    expect(fitManager.imported.single.metadata.name, "Test Fit");
    expect(fitManager.imported.single.body.shipTypeId, 12017);
  });

  test("efa scheme links import identically", () async {
    final uri = Uri.parse("efa://fit/raw?payload=${encodeFitLinkPayload(_makeFit())}");

    final result = await importer.import(uri);

    expect(result.fitId, "imported-id");
    expect(fitManager.imported, hasLength(1));
  });

  test("unknown paths throw FitLinkNotFoundException without touching storage", () async {
    await expectLater(
      importer.import(Uri.parse("https://share.platform.efa-tech.dev/other")),
      throwsA(isA<FitLinkNotFoundException>()),
    );
    expect(fitManager.imported, isEmpty);
  });

  test("malformed payloads throw FitLinkFormatException without touching storage", () async {
    for (final payload in ["EFA:abc", "EFA2:not_base64!!!", "EFA2:aGVsbG8"]) {
      await expectLater(
        importer.import(Uri.parse("efa://fit/raw?payload=$payload")),
        throwsA(isA<FitLinkFormatException>()),
        reason: payload,
      );
    }
    expect(fitManager.imported, isEmpty);
  });

  test("unsupported envelope version throws without touching storage", () async {
    final json = utf8.encode(
      jsonEncode(<String, dynamic>{"version": 99, "fit": <String, dynamic>{}}),
    );
    final compressed = const GZipEncoder().encodeBytes(json);
    final payload = "EFA2:${base64UrlEncode(compressed).replaceAll("=", "")}";

    await expectLater(
      importer.import(Uri.parse("efa://fit/raw?payload=$payload")),
      throwsA(isA<FitLinkFormatException>()),
    );
    expect(fitManager.imported, isEmpty);
  });
}
