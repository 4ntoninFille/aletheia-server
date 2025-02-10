use std::env;
use std::path::PathBuf;

use serde::Deserialize;

#[derive(Deserialize)]
pub struct Config {
    pub api: ApiConfig,
    pub logger: LoggerConfig,
    pub database: DatabaseConfig,
}

#[derive(Deserialize)]
pub struct ApiConfig {
    pub api_ip: String,
    pub api_port: u16,
    pub https: HttpsConfig,
}

#[derive(Deserialize)]
pub struct HttpsConfig {
    pub enabled: bool,
    pub cert_path: String,
    pub key_path: String,
    pub ca_bundle_path: String,
}

#[derive(Deserialize)]
pub struct LoggerConfig {
    pub filepath : String,
    pub rotation : String,
    pub global: String,
    pub tls: String,
    pub api: String,
}

#[derive(Deserialize)]
pub struct DatabaseConfig {
    pub url: String,
}

impl Config {
    pub fn from_file(path: &str) -> Result<Self, Box<dyn std::error::Error>> {
        let contents = std::fs::read_to_string(path)?;
        let mut config: Self = toml::from_str(&contents)?;

        // Override database URL with environment variable if set
        if let Ok(database_url) = env::var("DATABASE_URL") {
            config.database.url = database_url;
        }

        Ok(config)
    }
}

lazy_static! {
    pub static ref CONFIG: Config = {
        #[cfg(not(target_os = "windows"))]
        let config_paths = [
            PathBuf::from("conf/config.toml"),
        ];

        config_paths
            .iter()
            .find_map(|path| Config::from_file(path.to_str().unwrap_or_default()).ok())
            .expect("Failed to load config from any of the specified paths")
    };
}