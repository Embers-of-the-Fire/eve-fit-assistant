import "package:eve_fit_assistant/data/proto/fit.pb.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

enum SubsystemType {
  core,
  defensive,
  offensive,
  propulsion;

  factory SubsystemType.fromInt(int index) => SubsystemType.values[index];

  Subsystem_SubsystemType get protoEnum => switch (this) {
    SubsystemType.core => Subsystem_SubsystemType.CORE,
    SubsystemType.defensive => Subsystem_SubsystemType.DEFENSIVE,
    SubsystemType.offensive => Subsystem_SubsystemType.OFFENSIVE,
    SubsystemType.propulsion => Subsystem_SubsystemType.PROPULSION,
  };

  static const IList<SubsystemType> allTypes = IListConst([
    SubsystemType.core,
    SubsystemType.defensive,
    SubsystemType.offensive,
    SubsystemType.propulsion,
  ]);
}

extension SubsystemTypeExtension on Subsystem_SubsystemType {
  SubsystemType get toSubsystemType => switch (this) {
    Subsystem_SubsystemType.CORE => SubsystemType.core,
    Subsystem_SubsystemType.DEFENSIVE => SubsystemType.defensive,
    Subsystem_SubsystemType.OFFENSIVE => SubsystemType.offensive,
    Subsystem_SubsystemType.PROPULSION => SubsystemType.propulsion,
    _ => SubsystemType.core,
  };
}
