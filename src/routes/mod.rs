use actix_web::{middleware::Logger, web, App, HttpServer};
use health::info;
use product::product_info;
use anyhow::{Ok, Result};

pub mod health;
pub mod product;

#[actix_web::main]
pub async fn start_api() -> Result<()> {
let _ = HttpServer::new(|| {
        App::new()
            .wrap(Logger::default())
            .service(info)
            .service(
                web::scope("/v1/aletheia")
                    .route("/product/{barcode}", web::get().to(product_info))
            )
    })
    .bind(("127.0.0.1", 8080))?
    .run()
    .await;
    Ok(())
}