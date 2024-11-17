use std::sync::Arc;

use actix_web::{middleware::Logger, web, App, HttpServer};
use anyhow::{Ok, Result};
use health::info;
use product_routes::product_info;

use crate::db::{mongodb::MongodbOFF, product_trait::ProductTrait};

use super::{health, product_routes};

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
                web::scope("/v1/aletheia")
                    .route("/product/{barcode}", web::get().to(product_info)),
            )
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await;
    Ok(())
}
