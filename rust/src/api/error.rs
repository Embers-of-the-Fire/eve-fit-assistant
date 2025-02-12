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
        index: i32,
        error_key: ErrorKey,
    },
    Warning {
        slot: SlotType,
        index: i32,
        warning_key: WarningKey,
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ErrorKey {
    IncompatibleChargeSize { expected: u8, actual: u8 },
    IncompatibleChargeCapacity { max: f64, actual: f64 }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum WarningKey {
    MissingCharge,
}
