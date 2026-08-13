import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/utils/type_sort.dart";
import "package:flutter_test/flutter_test.dart";

pb_types.Type _type(int typeId, {int metaGroupId = 0, double? metaLevel}) {
  final type = pb_types.Type(typeId: typeId);
  if (metaGroupId != 0) type.metaGroupId = metaGroupId;
  if (metaLevel != null) {
    type.dogmaAttributes.add(
      pb_types.Type_DogmaAttributeValue(
        dogmaAttributeId: EveConstAttrID.metaLevel,
        value: metaLevel,
      ),
    );
  }
  return type;
}

void main() {
  group("compareTypesByMeta", () {
    test("orders by meta group: t1, t2, storyline, faction, deadspace, officer", () {
      final types = [
        _type(6, metaGroupId: EveConstMetaGroupId.officer),
        _type(5, metaGroupId: EveConstMetaGroupId.deadspace),
        _type(4, metaGroupId: EveConstMetaGroupId.faction),
        _type(3, metaGroupId: EveConstMetaGroupId.storyline),
        _type(2, metaGroupId: EveConstMetaGroupId.tech2),
        _type(1, metaGroupId: EveConstMetaGroupId.tech1),
      ]..sort(compareTypesByMeta);
      expect(types.map((t) => t.typeId), [1, 2, 3, 4, 5, 6]);
    });

    test("missing meta group sorts as tech 1", () {
      final types = [_type(2, metaGroupId: EveConstMetaGroupId.tech2), _type(1)]
        ..sort(compareTypesByMeta);
      expect(types.map((t) => t.typeId), [1, 2]);
    });

    test("orders by meta level within the same meta group", () {
      final types = [
        _type(3, metaGroupId: EveConstMetaGroupId.tech1, metaLevel: 4),
        _type(1, metaGroupId: EveConstMetaGroupId.tech1),
        _type(2, metaGroupId: EveConstMetaGroupId.tech1, metaLevel: 1),
      ]..sort(compareTypesByMeta);
      expect(types.map((t) => t.typeId), [1, 2, 3]);
    });

    test("falls back to type id for equal meta group and level", () {
      final types = [
        _type(2, metaGroupId: EveConstMetaGroupId.faction, metaLevel: 6),
        _type(1, metaGroupId: EveConstMetaGroupId.faction, metaLevel: 6),
      ]..sort(compareTypesByMeta);
      expect(types.map((t) => t.typeId), [1, 2]);
    });
  });
}
