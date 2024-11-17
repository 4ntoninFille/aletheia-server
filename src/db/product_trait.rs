use async_trait::async_trait;

use crate::models::product::Product;


#[derive(Debug)]
pub enum ProductTraitError {
    NotFound,
    DatabaseError(String),
}

#[async_trait]
pub trait ProductTrait: Send + Sync {
    async fn get_product_info(&self, barcode: String) -> Result<Product, ProductTraitError>;
    async fn get_products_info(&self, barcodes: Vec<String>) -> Result<Vec<Product>, ProductTraitError>;
}