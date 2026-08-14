import "dart:math";

import "package:eve_fit_assistant/features/fit_link/codec.dart";
import "package:eve_fit_assistant/features/fit_link/fit_link_uri.dart";
import "package:eve_fit_assistant/features/fit_link/share_link.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFit({String name = "Test Fit", String description = ""}) => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: name,
    lastModified: 0,
    description: description,
    checkoutRef: const CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: const FitStorageBody(
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
  dynamicRegistry: const FitDynamicRegistry(dynamicItems: IMap.empty()),
);

String _randomText(int length, int seed) {
  final random = Random(seed);
  const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return String.fromCharCodes(
    List.generate(length, (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length))),
  );
}

void main() {
  const builder = FitShareLinkBuilder();

  test("builds a share URL within the budget for a small fit", () {
    final url = builder.buildShareUrl(_makeFit());
    expect(url, isNotNull);
    expect(url, startsWith("https://share.platform.efa-tech.dev/fit/raw?payload=EFA2:"));
    expect(url!.length, lessThanOrEqualTo(maxFitLinkUrlLength));
  });

  test("returns null when the payload exceeds the budget", () {
    final fit = _makeFit(description: _randomText(20000, 42));
    expect(encodeFitLinkPayload(fit).length, greaterThan(maxFitLinkEncodedPayloadChars));
    expect(builder.buildShareUrl(fit), isNull);
  });

  test("budget boundary: every accepted URL stays within the limit", () {
    String? lastAccepted;
    String? firstRejected;
    for (var length = 0; length <= 12000 && firstRejected == null; length += 250) {
      final fit = _makeFit(description: _randomText(length, length));
      final url = builder.buildShareUrl(fit);
      if (url == null) {
        firstRejected = encodeFitLinkPayload(fit);
      } else {
        lastAccepted = url;
      }
    }
    expect(firstRejected, isNotNull);
    expect(lastAccepted, isNotNull);
    expect(lastAccepted!.length, lessThanOrEqualTo(maxFitLinkUrlLength));
    expect(firstRejected!.length, greaterThan(maxFitLinkEncodedPayloadChars));
  });
}
