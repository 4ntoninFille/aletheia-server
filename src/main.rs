use aletheia_server::{common::config::CONFIG, routes::start_api};
use tracing::info;
use tracing_appender::rolling;
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::{fmt, EnvFilter};


fn init_logger() {
    info!("Initializing logger...");
    let logs_dir = CONFIG.logger.filepath.as_str();
    let filename_prefix = "sakura.log";

    let file_appender = match CONFIG.logger.rotation.as_str() {
        "daily" => rolling::daily(logs_dir, filename_prefix),
        "hourly" => rolling::hourly(logs_dir, filename_prefix),
        "minutely" => rolling::minutely(logs_dir, filename_prefix),
        "never" => rolling::never(logs_dir, filename_prefix),
        _ => rolling::daily(logs_dir, filename_prefix),
    };

    let stdout_layer = fmt::layer().with_writer(std::io::stdout).event_format(
        fmt::format()
            .without_time()
            .with_level(true)
            .with_target(true)
            .compact(),
    );

    let file_layer = fmt::layer().with_writer(file_appender).with_ansi(false);

    let mut filter =
        EnvFilter::from_default_env().add_directive(CONFIG.logger.global.parse().unwrap());
    filter = filter.add_directive("h2=info".parse().unwrap());
    filter = filter.add_directive("hyper=info".parse().unwrap());
    filter = filter.add_directive(format!("rustls={}", CONFIG.logger.tls).parse().unwrap());
    filter = filter.add_directive(
        format!("Aletheia={}", CONFIG.logger.api)
            .parse()
            .unwrap(),
    );
    
    tracing_subscriber::registry()
        .with(filter)
        .with(stdout_layer)
        .with(file_layer)
        .init();
}

fn  main() {
    info!("Aletheia server started");
    init_logger();
    match start_api() {
        Ok(_) => {info!("Server Started");},
        Err(_) => {},
    };
}
