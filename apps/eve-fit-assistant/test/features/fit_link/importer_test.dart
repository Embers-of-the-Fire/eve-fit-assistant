@TestOn("vm")
library;

import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:archive/archive.dart";
import "package:dio/dio.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit.pb.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_link/importer.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
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

const _fitHash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);

  @override
  void close({bool force = false}) {}
}

FitState _makeFitState() => FitState(
  shipTypeId: 12017,
  layout: SnapshotShipLayout(
    highSlots: 1,
    mediumSlots: 0,
    lowSlots: 0,
    rigSlots: 0,
    subsystemSlots: 0,
    serviceSlots: 0,
    turretHardpoints: 1,
    launcherHardpoints: 0,
    fighterTubes: 0,
  ),
  damageProfile: DamageProfile(em: 0.25, thermal: 0.25, kinetic: 0.25, explosive: 0.25),
  modules: [
    FitModule(typeId: 12001, slotType: SlotType.HIGH, index: 0, state: Slots_SlotState.ACTIVE),
  ],
  character: FitCharacter(names: [const MapEntry("en", "All 5")]),
);

FitSnapshot _makeSnapshot() => FitSnapshot(
  version: 1,
  header: SnapshotHeader(
    fitName: "Registered Fit",
    description: "From the platform",
    lastModifiedMs: Int64(42),
    createdAtMs: Int64(43),
  ),
);

class _MemorySessionStore implements PlatformSessionStore {
  @override
  Future<StoredPlatformSession?> read() async => null;

  @override
  Future<void> write(StoredPlatformSession session) async {}

  @override
  Future<void> clear() async {}
}

PlatformSession _fakeSession(FitState? state, FitSnapshot? snapshot) {
  Dio createDio() => Dio(BaseOptions())
    ..httpClientAdapter = _FakeAdapter((options) async {
      if (options.path.endsWith("/state")) {
        if (state == null) {
          return ResponseBody.fromString(
            jsonEncode({"error": "not_found", "message": "unknown fit hash"}),
            404,
            headers: {
              Headers.contentTypeHeader: ["application/json"],
            },
          );
        }
        return ResponseBody.fromBytes(state.writeToBuffer(), 200);
      }
      if (snapshot == null) {
        return ResponseBody.fromString(
          jsonEncode({"error": "not_found", "message": "unknown fit hash"}),
          404,
          headers: {
            Headers.contentTypeHeader: ["application/json"],
          },
        );
      }
      return ResponseBody.fromBytes(snapshot.writeToBuffer(), 200);
    });
  return PlatformSession(
    origin: "https://test.invalid",
    store: _MemorySessionStore(),
    dioFactory: createDio,
  );
}

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
      "https://platform.efa-tech.dev/share/fit/raw?payload=${encodeEfaFitLinkPayload(encodeNativeFitPayload(fit))}",
    );

    final result = await importer.import(uri);

    expect(result.fitId, "imported-id");
    expect(fitManager.imported, hasLength(1));
    expect(fitManager.imported.single.metadata.name, "Test Fit");
    expect(fitManager.imported.single.body.shipTypeId, 12017);
  });

  test("efa scheme links import identically", () async {
    final uri = Uri.parse(
      "efa://fit/raw?payload=${encodeEfaFitLinkPayload(encodeNativeFitPayload(_makeFit()))}",
    );

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

  test("malformed payloads throw EfaFitFormatException without touching storage", () async {
    for (final payload in ["EFA:abc", "EFA2:not_base64!!!", "EFA2:aGVsbG8"]) {
      await expectLater(
        importer.import(Uri.parse("efa://fit/raw?payload=$payload")),
        throwsA(isA<EfaFitFormatException>()),
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
      throwsA(isA<EfaFitFormatException>()),
    );
    expect(fitManager.imported, isEmpty);
  });

  group("registered links", () {
    void overrideSession(PlatformSession session) {
      container = ProviderContainer.test(
        overrides: [
          fitManagerProvider.overrideWith(() => fitManager),
          platformSessionProvider.overrideWith((ref) async => session),
        ],
      );
      importer = FitLinkImporter(container.read(_refCaptureProvider));
    }

    test("imports the state fetched by fit hash, named from the snapshot", () async {
      overrideSession(_fakeSession(_makeFitState(), _makeSnapshot()));

      final result = await importer.import(
        Uri.parse("https://platform.efa-tech.dev/share/fit/registered?hash=$_fitHash"),
      );

      expect(result.fitId, "imported-id");
      final imported = fitManager.imported.single;
      expect(imported.metadata.name, "Registered Fit");
      expect(imported.metadata.description, "From the platform");
      expect(imported.body.shipTypeId, 12017);
      expect(imported.body.characterId, "predefined_all_5");
      expect(imported.body.slots.high, hasLength(1));
      expect(
        imported.body.slots.high[0].toNullable()?.itemId,
        const FitStorageItemId.item(id: 12001),
      );
    });

    test("imports via the efa scheme and boot URI forms", () async {
      overrideSession(_fakeSession(_makeFitState(), null));

      await importer.import(Uri.parse("efa://fit/registered?hash=$_fitHash"));
      await importer.importBootUri(
        Uri.parse("https://app.efa-tech.dev/fit/registered?hash=$_fitHash"),
      );

      expect(fitManager.imported, hasLength(2));
      // Without the snapshot, the name placeholder is left to the manager.
      expect(fitManager.imported.first.metadata.name, isEmpty);
    });

    test("an unknown fit hash throws FitLinkNotFoundException", () async {
      overrideSession(_fakeSession(null, null));

      await expectLater(
        importer.import(Uri.parse("efa://fit/registered?hash=$_fitHash")),
        throwsA(isA<FitLinkNotFoundException>()),
      );
      expect(fitManager.imported, isEmpty);
    });

    test("a malformed hash is rejected by the parser before any request", () async {
      overrideSession(_fakeSession(_makeFitState(), _makeSnapshot()));

      await expectLater(
        importer.import(Uri.parse("efa://fit/registered?hash=abc")),
        throwsA(isA<FitLinkNotFoundException>()),
      );
      expect(fitManager.imported, isEmpty);
    });
  });
}
