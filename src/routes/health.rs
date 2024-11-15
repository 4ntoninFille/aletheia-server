use actix_web::{get, HttpResponse, Responder};

#[get("/info")]
async fn info() -> impl Responder {
    HttpResponse::Ok().body("Welcome on Aletheia API")
}