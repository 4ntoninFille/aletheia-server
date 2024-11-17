use serde::Deserialize;


#[derive(Deserialize)]
pub struct SearchPayload {
    pub products: Vec<String>,
}
