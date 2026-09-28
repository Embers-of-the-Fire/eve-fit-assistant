import "package:efa_constant/eve.dart";
import "package:efa_proto/types.pb.dart" as pb_types;

int metaGroupRank(int metaGroupId) => switch (metaGroupId) {
  EveConstMetaGroupId.tech1 => 0,
  EveConstMetaGroupId.tech2 => 1,
  EveConstMetaGroupId.storyline => 2,
  EveConstMetaGroupId.faction => 3,
  EveConstMetaGroupId.deadspace => 4,
  EveConstMetaGroupId.officer => 5,
  _ => 0,
};

double metaLevelOf(pb_types.Type type) {
  for (final attribute in type.dogmaAttributes) {
    if (attribute.dogmaAttributeId == EveConstAttrID.metaLevel) {
      return attribute.value;
    }
  }
  return 0;
}

int compareTypesByMeta(pb_types.Type left, pb_types.Type right) {
  final rankCompare = metaGroupRank(left.metaGroupId).compareTo(metaGroupRank(right.metaGroupId));
  if (rankCompare != 0) return rankCompare;
  final metaCompare = metaLevelOf(left).compareTo(metaLevelOf(right));
  if (metaCompare != 0) return metaCompare;
  return left.typeId.compareTo(right.typeId);
}

/// Sort keys offered by the type database page.
enum TypeSortKey { name, typeId, metaLevel, group, category }

enum TypeSortDirection { ascending, descending }

int _compareNames(pb_types.Type left, pb_types.Type right, Map<int, String> names) {
  final leftName = names[left.typeId];
  final rightName = names[right.typeId];
  if (leftName == null && rightName == null) return 0;
  if (leftName == null) return 1;
  if (rightName == null) return -1;
  final byLowercase = leftName.toLowerCase().compareTo(rightName.toLowerCase());
  if (byLowercase != 0) return byLowercase;
  return leftName.compareTo(rightName);
}

/// Builds a comparator over [pb_types.Type] for [key] and [direction].
///
/// [names] maps type id to its localized name and is only consulted for
/// [TypeSortKey.name]; types without a resolved name sort after named ones.
/// [categoryOfGroup] resolves a group id to its category id and is only
/// consulted for [TypeSortKey.category]; unknown categories sort first.
/// Ties always break by type id so the ordering is stable.
Comparator<pb_types.Type> typeComparator(
  TypeSortKey key,
  TypeSortDirection direction, {
  Map<int, String> names = const {},
  int? Function(int groupId)? categoryOfGroup,
}) {
  int compareAscending(pb_types.Type left, pb_types.Type right) {
    final result = switch (key) {
      TypeSortKey.name => _compareNames(left, right, names),
      TypeSortKey.typeId => 0,
      TypeSortKey.metaLevel => compareTypesByMeta(left, right),
      TypeSortKey.group => left.groupId.compareTo(right.groupId),
      TypeSortKey.category => (categoryOfGroup?.call(left.groupId) ?? -1).compareTo(
        categoryOfGroup?.call(right.groupId) ?? -1,
      ),
    };
    if (result != 0) return result;
    return left.typeId.compareTo(right.typeId);
  }

  int compareDescending(pb_types.Type left, pb_types.Type right) {
    if (key == TypeSortKey.name) {
      final leftMissing = !names.containsKey(left.typeId);
      final rightMissing = !names.containsKey(right.typeId);
      if (leftMissing != rightMissing) return leftMissing ? 1 : -1;
    }
    return compareAscending(right, left);
  }

  return switch (direction) {
    TypeSortDirection.ascending => compareAscending,
    TypeSortDirection.descending => compareDescending,
  };
}

enum MetaFilterBucket { techTree, faction, deadspace, officer }

MetaFilterBucket metaFilterBucketOf(int metaGroupId) => switch (metaGroupId) {
  EveConstMetaGroupId.tech2 => MetaFilterBucket.techTree,
  EveConstMetaGroupId.storyline || EveConstMetaGroupId.faction => MetaFilterBucket.faction,
  EveConstMetaGroupId.deadspace => MetaFilterBucket.deadspace,
  EveConstMetaGroupId.officer => MetaFilterBucket.officer,
  _ => MetaFilterBucket.techTree,
};

class MetaFilter {
  const MetaFilter.all() : buckets = const {};
  const MetaFilter.buckets(this.buckets);

  final Set<MetaFilterBucket> buckets;

  bool get isAll => buckets.isEmpty;

  bool passes(pb_types.Type type) {
    if (isAll) return true;
    return buckets.contains(metaFilterBucketOf(type.metaGroupId));
  }

  MetaFilter toggleAll() => const MetaFilter.all();

  MetaFilter toggleBucket(MetaFilterBucket bucket) {
    final next = {...buckets};
    if (!next.remove(bucket)) next.add(bucket);
    return next.isEmpty ? const MetaFilter.all() : MetaFilter.buckets(next);
  }
}
