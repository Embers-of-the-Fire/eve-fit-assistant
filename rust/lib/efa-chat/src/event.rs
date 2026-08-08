#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ChatEvent {
    TextDelta(String),
    /// A new tool call started; `id` correlates the args deltas and the end
    /// event for this call.
    ToolCallStart {
        id: String,
        name: String,
    },
    /// Partial JSON argument data for the tool call with this `id`.
    ToolCallArgsDelta {
        id: String,
        delta: String,
    },
    /// The tool call with this `id` finished (a result was committed);
    /// `result` is the textual tool output returned to the model.
    ToolCallEnd {
        id: String,
        result: String,
    },
    Done(String),
    Error(String),
}
