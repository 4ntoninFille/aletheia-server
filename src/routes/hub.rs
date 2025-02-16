use std::sync::Arc;

use actix_web::{middleware::Logger, web, App, HttpServer};
use anyhow::{Ok, Result};
use health::info;
use product_info::product_info;

use crate::{common::config::CONFIG, db::{mongodb::MongodbOFF, product_trait::ProductTrait}};

use super::{health, product_info::{self, get_products_list}};

pub struct AppState {
    pub db: Arc<dyn ProductTrait + Send + Sync>,
}


#[actix_web::main]
pub async fn start_api() -> Result<()> {

    let mongodb_off = MongodbOFF::new().await;
    let db: Arc<dyn ProductTrait + Send + Sync> = Arc::new(mongodb_off);

    let _ = HttpServer::new(move || {
        
        let state = web::Data::new(AppState { db: db.clone() });

        App::new()
            .wrap(Logger::default())
            .app_data(state.clone())
            .service(info)
            .service(
                web::scope("api/v1/aletheia")
                    .route("/products/{barcode}", web::get().to(product_info))
                    .route("/products/search", web::post().to(get_products_list))
            )
    })
    .bind((CONFIG.api.api_ip.clone(), CONFIG.api.api_port))?
    .run()
    .await;
    Ok(())
}
