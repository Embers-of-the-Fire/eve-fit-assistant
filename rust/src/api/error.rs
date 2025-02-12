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

#[flutter_rust_bridge::frb(unignore, dart_metadata=("freezed"))]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SlotError {
    pub slot: SlotType,
    pub index: u32,
    pub error_key: ErrorKey,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ErrorKey {
    IncompatibleCharge { charge: u32 },
}

/// This function is used to force the frb to generate error defs.
pub fn error_echo(err: SlotError) -> SlotError {
    err
}
