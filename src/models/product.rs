use serde::{Deserialize, Serialize};

fn na() -> String {
    "NA".to_string()
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Product {
    pub code:               String,
    #[serde(default = "na")]
    pub product_name:       String,
    #[serde(default = "na")]
    pub nutriscore_grade:   String,
    #[serde(default = "na")]
    pub ecoscore_grade:     String,
    #[serde(default = "na")]
    pub nova_group:         String,
}