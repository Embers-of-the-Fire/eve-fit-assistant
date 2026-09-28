import "package:efa_constant/eve.dart";
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:eve_fit_assistant/utils/type_sort.dart";
import "package:flutter_test/flutter_test.dart";

pb_types.Type _type(int typeId, {int metaGroupId = 0, double? metaLevel, int groupId = 0}) {
  final type = pb_types.Type(typeId: typeId);
  if (metaGroupId != 0) type.metaGroupId = metaGroupId;
  if (groupId != 0) type.groupId = groupId;
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

  group("metaFilterBucketOf", () {
    test("maps meta groups to buckets", () {
      expect(metaFilterBucketOf(EveConstMetaGroupId.tech1), MetaFilterBucket.techTree);
      expect(metaFilterBucketOf(EveConstMetaGroupId.tech2), MetaFilterBucket.techTree);
      expect(metaFilterBucketOf(EveConstMetaGroupId.storyline), MetaFilterBucket.faction);
      expect(metaFilterBucketOf(EveConstMetaGroupId.faction), MetaFilterBucket.faction);
      expect(metaFilterBucketOf(EveConstMetaGroupId.deadspace), MetaFilterBucket.deadspace);
      expect(metaFilterBucketOf(EveConstMetaGroupId.officer), MetaFilterBucket.officer);
    });

    test("unknown or missing meta group maps to tech tree", () {
      expect(metaFilterBucketOf(0), MetaFilterBucket.techTree);
      expect(metaFilterBucketOf(99), MetaFilterBucket.techTree);
    });
  });

  group("typeComparator", () {
    test("type id sort orders by id with no key comparison", () {
      final types = [_type(3), _type(1), _type(2)]
        ..sort(typeComparator(TypeSortKey.typeId, TypeSortDirection.ascending));
      expect(types.map((t) => t.typeId), [1, 2, 3]);
    });

    test("name sort orders case-insensitively and breaks ties by type id", () {
      final names = {1: "beta", 2: "Alpha", 3: "alpha"};
      final types = [_type(1), _type(3), _type(2)]
        ..sort(typeComparator(TypeSortKey.name, TypeSortDirection.ascending, names: names));
      expect(types.map((t) => t.typeId), [2, 3, 1]);
    });

    test("name sort places types without a resolved name last", () {
      final names = {2: "Beta", 3: "Alpha"};
      final types = [_type(1), _type(2), _type(3)]
        ..sort(typeComparator(TypeSortKey.name, TypeSortDirection.ascending, names: names));
      expect(types.map((t) => t.typeId), [3, 2, 1]);
    });

    test("meta level sort delegates to meta ordering", () {
      final types = [
        _type(1, metaGroupId: EveConstMetaGroupId.officer),
        _type(2, metaGroupId: EveConstMetaGroupId.tech1),
        _type(3, metaGroupId: EveConstMetaGroupId.tech2),
      ]..sort(typeComparator(TypeSortKey.metaLevel, TypeSortDirection.ascending));
      expect(types.map((t) => t.typeId), [2, 3, 1]);
    });

    test("group sort orders by group id and breaks ties by type id", () {
      final types = [_type(3, groupId: 10), _type(2, groupId: 5), _type(1, groupId: 10)]
        ..sort(typeComparator(TypeSortKey.group, TypeSortDirection.ascending));
      expect(types.map((t) => t.typeId), [2, 1, 3]);
    });

    test("category sort uses the group lookup and sorts unknown categories first", () {
      final categories = {10: 7, 20: 6};
      final types = [_type(1, groupId: 10), _type(2, groupId: 30), _type(3, groupId: 20)]
        ..sort(
          typeComparator(
            TypeSortKey.category,
            TypeSortDirection.ascending,
            categoryOfGroup: (groupId) => categories[groupId],
          ),
        );
      expect(types.map((t) => t.typeId), [2, 3, 1]);
    });

    test("descending name sort keeps unnamed types last", () {
      final names = {2: "Beta", 3: "Alpha"};
      final types = [_type(1), _type(2), _type(3)]
        ..sort(typeComparator(TypeSortKey.name, TypeSortDirection.descending, names: names));
      expect(types.map((t) => t.typeId), [2, 3, 1]);
    });

    test("descending reverses the ascending order", () {
      final types = [_type(1), _type(2), _type(3)]
        ..sort(typeComparator(TypeSortKey.typeId, TypeSortDirection.descending));
      expect(types.map((t) => t.typeId), [3, 2, 1]);
    });
  });

  group("MetaFilter", () {
    test("all filter passes every type", () {
      const filter = MetaFilter.all();
      expect(filter.isAll, isTrue);
      expect(filter.passes(_type(1)), isTrue);
      expect(filter.passes(_type(2, metaGroupId: EveConstMetaGroupId.officer)), isTrue);
    });

    test("bucket filter passes only matching types", () {
      const filter = MetaFilter.buckets({MetaFilterBucket.techTree});
      expect(filter.isAll, isFalse);
      expect(filter.passes(_type(1, metaGroupId: EveConstMetaGroupId.tech1)), isTrue);
      expect(filter.passes(_type(2, metaGroupId: EveConstMetaGroupId.tech2)), isTrue);
      expect(filter.passes(_type(3, metaGroupId: EveConstMetaGroupId.faction)), isFalse);
      expect(filter.passes(_type(4)), isTrue);
    });

    test("toggleAll resets to all", () {
      const filter = MetaFilter.buckets({MetaFilterBucket.faction});
      expect(filter.toggleAll().isAll, isTrue);
    });

    test("toggleBucket leaves all state and selects the bucket", () {
      final filter = const MetaFilter.all().toggleBucket(MetaFilterBucket.deadspace);
      expect(filter.isAll, isFalse);
      expect(filter.buckets, {MetaFilterBucket.deadspace});
    });

    test("toggleBucket adds and removes buckets", () {
      final two = const MetaFilter.all()
          .toggleBucket(MetaFilterBucket.faction)
          .toggleBucket(MetaFilterBucket.officer);
      expect(two.buckets, {MetaFilterBucket.faction, MetaFilterBucket.officer});
      final one = two.toggleBucket(MetaFilterBucket.officer);
      expect(one.buckets, {MetaFilterBucket.faction});
    });

    test("removing the last bucket falls back to all", () {
      final filter = const MetaFilter.all().toggleBucket(MetaFilterBucket.faction);
      expect(filter.toggleBucket(MetaFilterBucket.faction).isAll, isTrue);
    });
  });
}
