import "package:eve_fit_assistant/constant/eve.dart";
import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;

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
