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
    Ship,
}

/// FRB DTO mirror of `eve_fit_os::validate::FighterSquadron`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FighterSquadron {
    Light,
    Support,
    Heavy,
}

/// FRB DTO mirror of `eve_fit_os::validate::ValidationState`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ValidationState {
    Passive,
    Online,
    Active,
    Overload,
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
    IncompatibleChargeSize {
        expected: u8,
        actual: u8,
    },
    IncompatibleChargeCapacity {
        max: f64,
        actual: f64,
    },
    IncompatibleChargeGroup {
        expected: Vec<i32>,
        actual: i32,
    },
    TooMuchTurret {
        expected: u8,
        actual: u8,
    },
    TooMuchLauncher {
        expected: u8,
        actual: u8,
    },
    ConflictItem {
        group_id: i32,
    },
    DuplicateBooster {
        slot: i32,
    },
    IncompatibleShipGroup {
        expected: Vec<i32>,
    },
    IncompatibleShipType {
        expected: Vec<i32>,
    },
    IncompatibleRigSize {
        expected: u8,
        actual: u8,
    },
    PowergridExceeded {
        expected: f64,
        actual: f64,
    },
    CpuExceeded {
        expected: f64,
        actual: f64,
    },
    CalibrationExceeded {
        expected: f64,
        actual: f64,
    },
    DroneBandwidthExceeded {
        expected: f64,
        actual: f64,
    },
    DroneBayExceeded {
        expected: f64,
        actual: f64,
    },
    TooManyActiveDrones {
        expected: u32,
        actual: u32,
    },
    TooMuchFighterTube {
        expected: u32,
        actual: u32,
    },
    TooMuchFighterSquadron {
        category: FighterSquadron,
        expected: u32,
        actual: u32,
    },
    StateExceedsMax {
        state: ValidationState,
        max_state: ValidationState,
    },
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
                engine::ValidationSlotType::Ship => ValidationSlotType::Ship,
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
            engine::ValidationErrorKey::PowergridExceeded { expected, actual } => {
                Self::PowergridExceeded { expected, actual }
            }
            engine::ValidationErrorKey::CpuExceeded { expected, actual } => {
                Self::CpuExceeded { expected, actual }
            }
            engine::ValidationErrorKey::CalibrationExceeded { expected, actual } => {
                Self::CalibrationExceeded { expected, actual }
            }
            engine::ValidationErrorKey::DroneBandwidthExceeded { expected, actual } => {
                Self::DroneBandwidthExceeded { expected, actual }
            }
            engine::ValidationErrorKey::DroneBayExceeded { expected, actual } => {
                Self::DroneBayExceeded { expected, actual }
            }
            engine::ValidationErrorKey::TooManyActiveDrones { expected, actual } => {
                Self::TooManyActiveDrones { expected, actual }
            }
            engine::ValidationErrorKey::TooMuchFighterTube { expected, actual } => {
                Self::TooMuchFighterTube { expected, actual }
            }
            engine::ValidationErrorKey::TooMuchFighterSquadron {
                category,
                expected,
                actual,
            } => Self::TooMuchFighterSquadron {
                category: match category {
                    engine::FighterSquadron::Light => FighterSquadron::Light,
                    engine::FighterSquadron::Support => FighterSquadron::Support,
                    engine::FighterSquadron::Heavy => FighterSquadron::Heavy,
                },
                expected,
                actual,
            },
            engine::ValidationErrorKey::StateExceedsMax { state, max_state } => {
                Self::StateExceedsMax {
                    state: ValidationState::from_engine(state),
                    max_state: ValidationState::from_engine(max_state),
                }
            }
        }
    }
}

impl ValidationState {
    fn from_engine(state: engine::ValidationState) -> Self {
        match state {
            engine::ValidationState::Passive => Self::Passive,
            engine::ValidationState::Online => Self::Online,
            engine::ValidationState::Active => Self::Active,
            engine::ValidationState::Overload => Self::Overload,
        }
    }
}
