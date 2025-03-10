use async_trait::async_trait;
use mongodb::{bson::doc, Client, Collection};

use crate::models::product::Product;

use super::product_trait::{ProductTrait, ProductTraitError};

pub struct MongodbOFF {
    collection: Collection<Product>,
}

impl MongodbOFF {
    pub async fn new() -> Self {
        let client = Client::with_uri_str("mongodb://localhost:27017")
        .await
        .expect("Failed to connect to MongoDB");

        let db = client.database("openfoodfact");

        MongodbOFF {
            collection: db.collection("products"),
        }
    }
}

#[async_trait]
impl ProductTrait for MongodbOFF {
    async fn get_product_info(&self, barcode: String) -> Result<Product, ProductTraitError> {
        let filter = doc! { "code": barcode };
        match self.collection.find_one(filter).await {
            Ok(Some(product)) => Ok(product),
            Ok(None) => Err(ProductTraitError::NotFound),
            Err(e) => Err(ProductTraitError::DatabaseError(e.to_string())),
        }
    }

    async fn get_products_info(
        &self,
        barcodes: Vec<String>,
    ) -> Result<Vec<Product>, ProductTraitError> {
        let filter = doc! { "code": { "$in": barcodes } };
        match self.collection.find(filter).await {
            Ok(mut cursor) => {
                let mut products = Vec::new();
                while cursor
                    .advance()
                    .await
                    .map_err(|e| ProductTraitError::DatabaseError(e.to_string()))?
                {
                    products.push(
                        cursor
                            .deserialize_current()
                            .map_err(|e| ProductTraitError::DatabaseError(e.to_string()))?,
                    );
                }

                Ok(products)
            }
            Err(e) => Err(ProductTraitError::DatabaseError(e.to_string())),
        }
    }
}
