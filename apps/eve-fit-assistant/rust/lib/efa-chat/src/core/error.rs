use thiserror::Error;

#[derive(Debug, Error)]
pub enum ChatError {
    #[error("invalid config: {0}")]
    InvalidConfig(String),

    #[error("client error: {0}")]
    Client(String),

    #[error("completion error: {0}")]
    Completion(String),

    #[error("stream error: {0}")]
    Stream(String),

    #[error("model listing error: {0}")]
    ModelListing(String),
}
