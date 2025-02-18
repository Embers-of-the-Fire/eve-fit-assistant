#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SlotType {
    High,
    Medium,
    Low,
    Rig,
    Subsystem,
    Implant,
    Drone,
}

#[flutter_rust_bridge::frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SlotInfo {
    Error {
        slot: SlotType,
        index: Option<i32>,
        error_key: ErrorKey,
    },
    Warning {
        slot: SlotType,
        index: Option<i32>,
        warning_key: WarningKey,
    },
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ErrorKey {
    // charge
    IncompatibleChargeSize { expected: u8, actual: u8 },
    IncompatibleChargeCapacity { max: f64, actual: f64 },
    // slot num
    TooMuchTurret { expected: u8, actual: u8 },
    TooMuchLauncher { expected: u8, actual: u8 },
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum WarningKey {
    MissingCharge,
    // used to let `frb` know that this enum has variants with fields
    // TODO: remove this once we have actual warning keys with fields
    Placeholder(i32),
}
