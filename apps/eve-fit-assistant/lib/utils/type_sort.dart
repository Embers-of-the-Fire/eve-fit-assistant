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
