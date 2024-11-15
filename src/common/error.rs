use std::fmt;
use actix_web::{http::StatusCode, HttpResponse, ResponseError};
use serde::Serialize;

#[derive(Debug)]
#[repr(u16)]
pub enum JsonErrorResponse {
    BadRequest(String) = 400,
    Unauthorized(String) = 401,
    PayloadTooLarge(String) = 413,
    InternalServerError(String) = 500,
}

#[derive(Serialize)]
struct ErrorResponse {
    status: u16,
    error: String,
}

impl JsonErrorResponse {
    pub fn from_status_code(status_code: u16, message: String) -> JsonErrorResponse {
        match status_code {
            400 => JsonErrorResponse::BadRequest(message),
            401 => JsonErrorResponse::Unauthorized(message),
            413 => JsonErrorResponse::PayloadTooLarge(message),
            500 => JsonErrorResponse::InternalServerError(message),
            _ => JsonErrorResponse::InternalServerError(message),
        }
    }

    fn message(&self) -> &str {
        match *self {
            JsonErrorResponse::BadRequest(ref message)
            | JsonErrorResponse::Unauthorized(ref message)
            | JsonErrorResponse::PayloadTooLarge(ref message)
            | JsonErrorResponse::InternalServerError(ref message) => message,
        }
    }
}

impl fmt::Display for JsonErrorResponse {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.message())
    }
}

impl ResponseError for JsonErrorResponse {
    fn status_code(&self) -> StatusCode {
        match *self {
            JsonErrorResponse::BadRequest(_) => StatusCode::BAD_REQUEST,
            JsonErrorResponse::PayloadTooLarge(_) => StatusCode::PAYLOAD_TOO_LARGE,
            JsonErrorResponse::InternalServerError(_) => StatusCode::INTERNAL_SERVER_ERROR,
            JsonErrorResponse::Unauthorized(_) => StatusCode::UNAUTHORIZED,
        }
    }

    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(self.status_code()).json(ErrorResponse {
            status: self.status_code().as_u16(),
            error: self.to_string(),
        })
    }
}