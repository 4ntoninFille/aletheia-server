use actix_web::{web, HttpResponse};

use crate::{common::error::JsonErrorResponse, db::product_trait::ProductTraitError};

use super::hub::AppState;

pub async fn product_info(
    state: web::Data<AppState>,
    info: web::Path<String>
) -> Result<HttpResponse, JsonErrorResponse> {
    let barcode = info.into_inner();
    
    // Use the ProductTrait implementation to get product info
    match state.db.get_product_info(barcode).await {
        Ok(product) => Ok(HttpResponse::Ok().json(product)),
        Err(ProductTraitError::NotFound) => Ok(HttpResponse::NotFound().json("Product not found")),
        Err(_) => Ok(HttpResponse::InternalServerError().json("An error occurred")),
    }
}