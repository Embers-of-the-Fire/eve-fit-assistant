import "package:efa_fit/efa_fit.dart";
import "package:flutter_test/flutter_test.dart";

// A real zKillboard /api/killID/126861807/ response, trimmed to the fields the
// parser consumes (attackers/position/zkb omitted).
const _zkillSample = """
[{
  "killmail_id": 126861807,
  "killmail_time": "2025-05-05T20:18:06Z",
  "solar_system_id": 31002503,
  "victim": {
    "character_id": 2113520265,
    "ship_type_id": 11985,
    "items": [
      {"flag": 28, "item_type_id": 16487, "quantity_dropped": 1, "singleton": 0},
      {"flag": 27, "item_type_id": 8641, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 19, "item_type_id": 35660, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 22, "item_type_id": 3841, "quantity_dropped": 1, "singleton": 0},
      {"flag": 31, "item_type_id": 16487, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 93, "item_type_id": 31796, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 23, "item_type_id": 2281, "quantity_dropped": 1, "singleton": 0},
      {"flag": 5, "item_type_id": 1541, "quantity_dropped": 1, "singleton": 0},
      {"flag": 5, "item_type_id": 35656, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 21, "item_type_id": 2301, "quantity_dropped": 1, "singleton": 0},
      {"flag": 92, "item_type_id": 31796, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 20, "item_type_id": 3841, "quantity_dropped": 1, "singleton": 0},
      {"flag": 30, "item_type_id": 8641, "quantity_dropped": 1, "singleton": 0},
      {"flag": 12, "item_type_id": 2048, "quantity_dropped": 1, "singleton": 0},
      {"flag": 11, "item_type_id": 1355, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 5, "item_type_id": 28668, "quantity_destroyed": 100, "singleton": 0},
      {"flag": 87, "item_type_id": 2488, "quantity_destroyed": 5, "singleton": 0},
      {"flag": 32, "item_type_id": 8635, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 29, "item_type_id": 8641, "quantity_dropped": 1, "singleton": 0}
    ]
  }
}]
""";

void main() {
  group("parseKillmailJson", () {
    test("parses a zKillboard list response", () {
      final killmail = parseKillmailJson(_zkillSample);

      expect(killmail.killmailId, 126861807);
      expect(killmail.shipTypeId, 11985);
      expect(killmail.killmailTime, DateTime.utc(2025, 5, 5, 20, 18, 6));
      expect(killmail.items, hasLength(19));
      expect(killmail.items.first.flag, 28);
      expect(killmail.items.first.typeId, 16487);
      expect(killmail.items.first.quantity, 1);
    });

    test("parses a bare ESI killmail object", () {
      final killmail = parseKillmailJson(
        '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": []}}',
      );

      expect(killmail.killmailId, 1);
      expect(killmail.shipTypeId, 638);
      expect(killmail.killmailTime, isNull);
      expect(killmail.items, isEmpty);
    });

    test("sums dropped and destroyed quantities", () {
      final killmail = parseKillmailJson(
        '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": ['
        '{"flag": 87, "item_type_id": 3001, "quantity_dropped": 2, "quantity_destroyed": 3}'
        "]}}",
      );

      expect(killmail.items.single.quantity, 5);
    });

    test("rejects non-JSON input", () {
      expect(() => parseKillmailJson("not json"), throwsA(isA<KillmailFormatException>()));
    });

    test("rejects JSON without victim", () {
      expect(
        () => parseKillmailJson('{"killmail_id": 1}'),
        throwsA(isA<KillmailFormatException>()),
      );
    });

    test("rejects empty list", () {
      expect(() => parseKillmailJson("[]"), throwsA(isA<KillmailFormatException>()));
    });
  });

  group("killmailFlagToRack", () {
    test("maps module slot flags", () {
      expect(killmailFlagToRack(11), (KillmailRack.low, 0));
      expect(killmailFlagToRack(18), (KillmailRack.low, 7));
      expect(killmailFlagToRack(19), (KillmailRack.medium, 0));
      expect(killmailFlagToRack(26), (KillmailRack.medium, 7));
      expect(killmailFlagToRack(27), (KillmailRack.high, 0));
      expect(killmailFlagToRack(34), (KillmailRack.high, 7));
      expect(killmailFlagToRack(92), (KillmailRack.rig, 0));
      expect(killmailFlagToRack(94), (KillmailRack.rig, 2));
      expect(killmailFlagToRack(125), (KillmailRack.subsystem, 0));
      expect(killmailFlagToRack(128), (KillmailRack.subsystem, 3));
      expect(killmailFlagToRack(164), (KillmailRack.service, 0));
      expect(killmailFlagToRack(171), (KillmailRack.service, 7));
    });

    test("returns null for non-module flags", () {
      expect(killmailFlagToRack(5), isNull);
      expect(killmailFlagToRack(87), isNull);
      expect(killmailFlagToRack(155), isNull);
      expect(killmailFlagToRack(159), isNull);
      expect(killmailFlagToRack(0), isNull);
      expect(killmailFlagToRack(999), isNull);
    });
  });

  group("killmailToFit", () {
    test("reconstructs the zKillboard sample fitting", () {
      final fit = killmailToFit(parseKillmailJson(_zkillSample));

      expect(fit.killmailId, 126861807);
      expect(fit.shipTypeId, 11985);
      expect(fit.racks[KillmailRack.high], {
        0: [8641],
        1: [16487],
        2: [8641],
        3: [8641],
        4: [16487],
        5: [8635],
      });
      expect(fit.racks[KillmailRack.medium], {
        0: [35660],
        1: [3841],
        2: [2301],
        3: [3841],
        4: [2281],
      });
      expect(fit.racks[KillmailRack.low], {
        0: [1355],
        1: [2048],
      });
      expect(fit.racks[KillmailRack.rig], {
        0: [31796],
        1: [31796],
      });
      expect(fit.drones, hasLength(1));
      expect(fit.drones.single.typeId, 2488);
      expect(fit.drones.single.quantity, 5);
      expect(fit.fighters, isEmpty);
      expect(fit.skippedTypeIds, isEmpty);
    });

    test("merges drone stacks and fighter tubes by type", () {
      final fit = killmailToFit(
        parseKillmailJson(
          '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": ['
          '{"flag": 87, "item_type_id": 3001, "quantity_dropped": 2, "quantity_destroyed": 3},'
          '{"flag": 155, "item_type_id": 3002, "quantity_destroyed": 3},'
          '{"flag": 159, "item_type_id": 3002, "quantity_destroyed": 1},'
          '{"flag": 160, "item_type_id": 3002, "quantity_destroyed": 1}'
          "]}}",
        ),
      );

      expect(fit.drones.single.typeId, 3001);
      expect(fit.drones.single.quantity, 5);
      expect(fit.fighters.single.typeId, 3002);
      expect(fit.fighters.single.quantity, 5);
    });

    test("drops cargo and reports unknown flags as skipped", () {
      final fit = killmailToFit(
        parseKillmailJson(
          '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": ['
          '{"flag": 5, "item_type_id": 2001, "quantity_destroyed": 10},'
          '{"flag": 133, "item_type_id": 2002, "quantity_destroyed": 1}'
          "]}}",
        ),
      );

      expect(fit.racks, isEmpty);
      expect(fit.skippedTypeIds, [2002]);
    });

    test("preserves all same-flag candidates (module and loaded charge)", () {
      final fit = killmailToFit(
        parseKillmailJson(
          '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": ['
          '{"flag": 27, "item_type_id": 1003, "quantity_destroyed": 1, "singleton": 0},'
          '{"flag": 27, "item_type_id": 2003, "quantity_destroyed": 200, "singleton": 0}'
          "]}}",
        ),
      );

      expect(fit.racks[KillmailRack.high], {
        0: [1003, 2003],
      });
      expect(fit.skippedTypeIds, isEmpty);
    });

    test("ignores items with zero quantity", () {
      final fit = killmailToFit(
        parseKillmailJson(
          '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": ['
          '{"flag": 27, "item_type_id": 1003, "singleton": 0}'
          "]}}",
        ),
      );

      expect(fit.racks, isEmpty);
    });
  });
}
