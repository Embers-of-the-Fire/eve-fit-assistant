import "package:eve_fit_assistant/data/proto/types.pb.dart" as pb_types;

extension SkillTypeAlphaCloneLevel on pb_types.Type {
  int get alphaCloneMaxLevel => hasAlphaMaxLevel() ? alphaMaxLevel : 0;
}
