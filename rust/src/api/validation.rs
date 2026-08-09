use eve_fit_os::validate as engine;

/// FRB DTO mirror of `eve_fit_os::validate::ValidationSlotType`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValidationSlotType {
    High,
    Medium,
    Low,
    Rig,
    SubSystem,
    Service,
    TacticalMode,
    Implant,
    Booster,
    Drone,
    Fighter,
}

/// FRB DTO mirror of `eve_fit_os::validate::ValidationIssue`.
#[derive(Debug, Clone, PartialEq)]
pub struct ValidationIssue {
    pub slot_type: ValidationSlotType,
    pub index: Option<i32>,
    pub kind: ValidationIssueKind,
}

/// FRB DTO mirror of `eve_fit_os::validate::ValidationIssueKind`.
#[derive(Debug, Clone, PartialEq)]
pub enum ValidationIssueKind {
    Error(ValidationErrorKey),
    Warning(ValidationWarningKey),
}

/// FRB DTO mirror of `eve_fit_os::validate::ValidationErrorKey`.
#[derive(Debug, Clone, PartialEq)]
pub enum ValidationErrorKey {
    IncompatibleChargeSize { expected: u8, actual: u8 },
    IncompatibleChargeCapacity { max: f64, actual: f64 },
    IncompatibleChargeGroup { expected: Vec<i32>, actual: i32 },
    TooMuchTurret { expected: u8, actual: u8 },
    TooMuchLauncher { expected: u8, actual: u8 },
    ConflictItem { group_id: i32 },
    DuplicateBooster { slot: i32 },
    IncompatibleShipGroup { expected: Vec<i32> },
    IncompatibleShipType { expected: Vec<i32> },
    IncompatibleRigSize { expected: u8, actual: u8 },
}

/// FRB DTO mirror of `eve_fit_os::validate::ValidationWarningKey`.
#[derive(Debug, Clone, PartialEq)]
pub enum ValidationWarningKey {
    MissingCharge,
}

impl ValidationIssue {
    pub(crate) fn from_engine(issue: engine::ValidationIssue) -> Self {
        Self {
            slot_type: match issue.slot_type {
                engine::ValidationSlotType::High => ValidationSlotType::High,
                engine::ValidationSlotType::Medium => ValidationSlotType::Medium,
                engine::ValidationSlotType::Low => ValidationSlotType::Low,
                engine::ValidationSlotType::Rig => ValidationSlotType::Rig,
                engine::ValidationSlotType::SubSystem => ValidationSlotType::SubSystem,
                engine::ValidationSlotType::Service => ValidationSlotType::Service,
                engine::ValidationSlotType::TacticalMode => ValidationSlotType::TacticalMode,
                engine::ValidationSlotType::Implant => ValidationSlotType::Implant,
                engine::ValidationSlotType::Booster => ValidationSlotType::Booster,
                engine::ValidationSlotType::Drone => ValidationSlotType::Drone,
                engine::ValidationSlotType::Fighter => ValidationSlotType::Fighter,
            },
            index: issue.index,
            kind: match issue.kind {
                engine::ValidationIssueKind::Error(key) => {
                    ValidationIssueKind::Error(ValidationErrorKey::from_engine(key))
                }
                engine::ValidationIssueKind::Warning(key) => {
                    ValidationIssueKind::Warning(match key {
                        engine::ValidationWarningKey::MissingCharge => {
                            ValidationWarningKey::MissingCharge
                        }
                    })
                }
            },
        }
    }
}

impl ValidationErrorKey {
    fn from_engine(key: engine::ValidationErrorKey) -> Self {
        match key {
            engine::ValidationErrorKey::IncompatibleChargeSize { expected, actual } => {
                Self::IncompatibleChargeSize { expected, actual }
            }
            engine::ValidationErrorKey::IncompatibleChargeCapacity { max, actual } => {
                Self::IncompatibleChargeCapacity { max, actual }
            }
            engine::ValidationErrorKey::IncompatibleChargeGroup { expected, actual } => {
                Self::IncompatibleChargeGroup { expected, actual }
            }
            engine::ValidationErrorKey::TooMuchTurret { expected, actual } => {
                Self::TooMuchTurret { expected, actual }
            }
            engine::ValidationErrorKey::TooMuchLauncher { expected, actual } => {
                Self::TooMuchLauncher { expected, actual }
            }
            engine::ValidationErrorKey::ConflictItem { group_id } => {
                Self::ConflictItem { group_id }
            }
            engine::ValidationErrorKey::DuplicateBooster { slot } => {
                Self::DuplicateBooster { slot }
            }
            engine::ValidationErrorKey::IncompatibleShipGroup { expected } => {
                Self::IncompatibleShipGroup { expected }
            }
            engine::ValidationErrorKey::IncompatibleShipType { expected } => {
                Self::IncompatibleShipType { expected }
            }
            engine::ValidationErrorKey::IncompatibleRigSize { expected, actual } => {
                Self::IncompatibleRigSize { expected, actual }
            }
        }
    }
}
