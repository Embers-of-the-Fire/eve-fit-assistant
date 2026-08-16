import "package:efa_fit/efa_fit.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeResolver implements EftTypeResolver {
  static const shipId = 638;
  static const lowModuleId = 1001;
  static const medModuleId = 1002;
  static const highModuleId = 1003;
  static const chargeId = 2001;
  static const droneId = 3001;
  static const fighterId = 3002;
  static const implantId = 4001;
  static const boosterId = 4002;

  static const _names = {
    shipId: "Raven",
    lowModuleId: "Ballistic Control System II",
    medModuleId: "Large Shield Extender II",
    highModuleId: "Cruise Missile Launcher II",
    chargeId: "Scourge Cruise Missile",
    droneId: "Hobgoblin II",
    fighterId: "Einherji",
    implantId: "Mid-grade Snake Alpha",
    boosterId: "Strong Blue Pill Booster",
  };

  static final _byName = {for (final entry in _names.entries) entry.value: entry.key};

  @override
  int? resolveTypeId(String name) => _byName[name.trim()];

  @override
  int? resolveShipId(String name) => name.trim() == "Raven" ? shipId : resolveTypeId(name);

  @override
  bool isShip(int typeId) => typeId == shipId;

  @override
  EftRack? rackOf(int typeId) => switch (typeId) {
    lowModuleId => EftRack.low,
    medModuleId => EftRack.medium,
    highModuleId => EftRack.high,
    _ => null,
  };

  @override
  int? implantSlotOf(int typeId) => typeId == implantId ? 1 : null;

  @override
  int? boosterSlotOf(int typeId) => typeId == boosterId ? 3 : null;

  @override
  bool isDrone(int typeId) => typeId == droneId;

  @override
  bool isFighter(int typeId) => typeId == fighterId;

  String? typeName(int typeId) => _names[typeId];
}

final _resolver = _FakeResolver();

void main() {
  group("parseEft", () {
    test("parses a header-only fit", () {
      final fit = parseEft("[Raven, Empty]", resolver: _resolver);
      expect(fit.shipTypeId, _FakeResolver.shipId);
      expect(fit.name, "Empty");
      expect(fit.racks, isEmpty);
    });

    test("parses module racks with charges, offline states and placeholders", () {
      final fit = parseEft(
        "[Raven, PvP]\n"
        "\n"
        "Ballistic Control System II\n"
        "[Empty Low slot]\n"
        "\n"
        "Large Shield Extender II /offline\n"
        "\n"
        "Cruise Missile Launcher II, Scourge Cruise Missile\n",
        resolver: _resolver,
      );

      final low = fit.racks[EftRack.low]!;
      expect(low.length, 2);
      expect(low[0]!.typeId, _FakeResolver.lowModuleId);
      expect(low[0]!.online, isTrue);
      expect(low[1], isNull);

      final medium = fit.racks[EftRack.medium]!;
      expect(medium.single!.online, isFalse);

      final high = fit.racks[EftRack.high]!;
      expect(high.single!.chargeTypeId, _FakeResolver.chargeId);
    });

    test("parses drones and fighters from count lines", () {
      final fit = parseEft(
        "[Raven, Minions]\n\nHobgoblin II x5\n\nEinherji x3\n",
        resolver: _resolver,
      );
      expect(fit.drones.single.typeId, _FakeResolver.droneId);
      expect(fit.drones.single.quantity, 5);
      expect(fit.fighters.single.typeId, _FakeResolver.fighterId);
      expect(fit.fighters.single.quantity, 3);
    });

    test("parses implants and boosters sorted by slot", () {
      final fit = parseEft(
        "[Raven, Pod]\n\nStrong Blue Pill Booster\nMid-grade Snake Alpha\n",
        resolver: _resolver,
      );
      expect(fit.implants, [_FakeResolver.implantId]);
      expect(fit.boosters.single.typeId, _FakeResolver.boosterId);
      expect(fit.boosters.single.slotIndex, 3);
    });

    test("rejects an unknown ship name", () {
      expect(
        () => parseEft("[No Such Ship, X]", resolver: _resolver),
        throwsA(
          isA<EftFormatException>().having((e) => e.code, "code", EftFormatErrorCode.unknownType),
        ),
      );
    });

    test("rejects a non-ship type in the header", () {
      expect(
        () => parseEft("[Hobgoblin II, X]", resolver: _resolver),
        throwsA(
          isA<EftFormatException>().having(
            (e) => e.code,
            "code",
            EftFormatErrorCode.unavailableShip,
          ),
        ),
      );
    });

    test("rejects a malformed header", () {
      for (final text in ["", "[Raven]", "Raven, X"]) {
        expect(
          () => parseEft(text, resolver: _resolver),
          throwsA(
            isA<EftFormatException>().having((e) => e.code, "code", EftFormatErrorCode.invalid),
          ),
          reason: text,
        );
      }
    });

    test("rejects an unknown module inside a rack block", () {
      expect(
        () => parseEft(
          "[Raven, X]\n\nBallistic Control System II\nMystery Module\n",
          resolver: _resolver,
        ),
        throwsA(
          isA<EftFormatException>()
              .having((e) => e.code, "code", EftFormatErrorCode.unknownType)
              .having((e) => e.detail, "detail", "Mystery Module"),
        ),
      );
    });

    test("rejects mixed racks in one block", () {
      expect(
        () => parseEft(
          "[Raven, X]\n\nBallistic Control System II\nLarge Shield Extender II\n",
          resolver: _resolver,
        ),
        throwsA(
          isA<EftFormatException>().having((e) => e.code, "code", EftFormatErrorCode.invalid),
        ),
      );
    });

    test("rejects count lines for non-minion types", () {
      expect(
        () => parseEft("[Raven, X]\n\nBallistic Control System II x2\n", resolver: _resolver),
        throwsA(
          isA<EftFormatException>().having((e) => e.code, "code", EftFormatErrorCode.invalid),
        ),
      );
    });
  });

  group("formatEft", () {
    test("formats a header-only fit with a trailing newline", () {
      final text = formatEft(
        const EftFit(shipTypeId: _FakeResolver.shipId, name: "Empty"),
        typeName: _resolver.typeName,
      );
      expect(text, "[Raven, Empty]\n");
    });

    test("formats racks, minions and character sections in canonical order", () {
      const fit = EftFit(
        shipTypeId: _FakeResolver.shipId,
        name: "PvP",
        racks: {
          EftRack.low: [EftModule(typeId: _FakeResolver.lowModuleId), null],
          EftRack.high: [
            EftModule(
              typeId: _FakeResolver.highModuleId,
              chargeTypeId: _FakeResolver.chargeId,
              online: false,
            ),
          ],
        },
        drones: [EftStack(typeId: _FakeResolver.droneId, quantity: 5)],
        fighters: [EftStack(typeId: _FakeResolver.fighterId, quantity: 3)],
        implants: [_FakeResolver.implantId],
        boosters: [EftSlottedItem(typeId: _FakeResolver.boosterId, slotIndex: 3)],
      );

      final text = formatEft(fit, typeName: _resolver.typeName);

      expect(
        text,
        "[Raven, PvP]\n"
        "\n"
        "Ballistic Control System II\n"
        "[Empty Low slot]\n"
        "\n"
        "Cruise Missile Launcher II, Scourge Cruise Missile /offline\n"
        "\n"
        "\n"
        "Hobgoblin II x5\n"
        "\n"
        "Einherji x3\n"
        "\n"
        "\n"
        "Mid-grade Snake Alpha\n"
        "\n"
        "Strong Blue Pill Booster\n",
      );
    });

    test("falls back to a placeholder name for unknown types", () {
      final text = formatEft(
        const EftFit(shipTypeId: 99999, name: "X"),
        typeName: _resolver.typeName,
      );
      expect(text, "[Unknown Type[99999], X]\n");
    });

    test("round-trips through parseEft", () {
      const fit = EftFit(
        shipTypeId: _FakeResolver.shipId,
        name: "Round Trip",
        racks: {
          EftRack.low: [EftModule(typeId: _FakeResolver.lowModuleId), null],
          EftRack.medium: [EftModule(typeId: _FakeResolver.medModuleId, online: false)],
          EftRack.high: [
            EftModule(typeId: _FakeResolver.highModuleId, chargeTypeId: _FakeResolver.chargeId),
          ],
        },
        drones: [EftStack(typeId: _FakeResolver.droneId, quantity: 2)],
        fighters: [EftStack(typeId: _FakeResolver.fighterId, quantity: 1)],
        implants: [_FakeResolver.implantId],
        boosters: [EftSlottedItem(typeId: _FakeResolver.boosterId, slotIndex: 3)],
      );

      final parsed = parseEft(formatEft(fit, typeName: _resolver.typeName), resolver: _resolver);

      expect(parsed.shipTypeId, fit.shipTypeId);
      expect(parsed.name, fit.name);
      expect(parsed.racks[EftRack.low]!.length, 2);
      expect(parsed.racks[EftRack.low]![0]!.typeId, _FakeResolver.lowModuleId);
      expect(parsed.racks[EftRack.low]![1], isNull);
      expect(parsed.racks[EftRack.medium]!.single!.online, isFalse);
      expect(parsed.racks[EftRack.high]!.single!.chargeTypeId, _FakeResolver.chargeId);
      expect(parsed.drones.single.quantity, 2);
      expect(parsed.fighters.single.typeId, _FakeResolver.fighterId);
      expect(parsed.implants, [_FakeResolver.implantId]);
      expect(parsed.boosters.single.slotIndex, 3);
    });
  });
}
