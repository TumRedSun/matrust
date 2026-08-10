//! Centralized error types.

use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("matrix error: {0}")]
    Matrix(#[from] matrix_sdk::Error),

    #[error("http error: {0}")]
    Http(#[from] matrix_sdk::HttpError),

    #[error("io error: {0}")]
    Io(#[from] std::io::Error),

    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("url parse error: {0}")]
    Url(#[from] url::ParseError),

    #[error("not logged in")]
    NotLoggedIn,

    #[error("room not found: {0}")]
    RoomNotFound(String),

    #[error("file error: {0}")]
    File(String),

    #[error("anyhow error: {0}")]
    Anyhow(#[from] anyhow::Error),

    #[error("{0}")]
    Other(String),
}

pub type AppResult<T> = Result<T, AppError>;
