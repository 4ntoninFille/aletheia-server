use actix_web::{web, HttpResponse};

use crate::common::error::JsonErrorResponse;

pub async fn product_info(info: web::Path<String>) -> Result<HttpResponse, JsonErrorResponse> {
    let barccode = info.into_inner();
    let response_body = format!("Hello World !!!, {}", barccode);
    Ok(HttpResponse::Ok().json(response_body))
}