import "package:efa_proto/types.pb.dart" as pb_types;

extension SkillTypeAlphaCloneLevel on pb_types.Type {
  int get alphaCloneMaxLevel => hasAlphaMaxLevel() ? alphaMaxLevel : 0;
}
