use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
pub struct Product {
    pub code:               String,
    pub product_name:       String,
    pub nutriscore_grade:   String,
    pub ecoscore_grade:     String,
}