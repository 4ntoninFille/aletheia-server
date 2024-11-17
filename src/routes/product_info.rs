use actix_web::{web, HttpResponse};
use serde_json::json;

use crate::{common::error::JsonErrorResponse, db::product_trait::ProductTraitError};

use super::{hub::AppState, product_format::SearchPayload};

// GET /v1/aletheia/product/{barcode}
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

// POST /v1/aletheia/products/search
pub async fn get_products_list(
    state: web::Data<AppState>,
    payload: web::Json<SearchPayload>,
) -> Result<HttpResponse, JsonErrorResponse> {
    let products = payload.products.clone();
    
    // Use the ProductTrait implementation to get product info
    match state.db.get_products_info(products).await {
        Ok(product_info) => {
            let response = json!({
                "products_info": product_info
            });
            Ok(HttpResponse::Ok().json(response))
        },
        Err(ProductTraitError::NotFound) => {
            Ok(HttpResponse::NotFound().json("Products not found"))
        },
        Err(_) => {
            Ok(HttpResponse::InternalServerError().json("An error occurred"))
        },
    }
}