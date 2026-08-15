/// AcilBir Server Configuration Recovery & Dynamic Bootstrap
///
/// Uygulama açılışında ve periyodik olarak `/api/server-key` endpoint'inden
/// sunucu konfigürasyonunu (ID server, relay, API server, key) çeker ve uygular.
/// Sunucu bilgileri değiştiğinde mevcut istemciler otomatik güncellenir.
///
/// Öncelik:
/// 1. API'den çekilen değerler → RustDesk2.toml [options]'a yazılır
/// 2. custom_.txt varsa → HARD_SETTINGS daha yüksek önceliğe sahip
/// 3. API erişilemezse → mevcut config korunur (graceful degradation)
use hbb_common::{config::Config, log};
use serde::Deserialize;
use std::time::Duration;

/// Go API'nin /api/server-key response formatı
#[derive(Debug, Deserialize)]
struct ServerKeyResponse {
    #[serde(default)]
    key: String,
    #[serde(default)]
    id_server: String,
    #[serde(default)]
    relay: String,
    #[serde(default)]
    api_server: String,
}

/// Arka plan thread'i başlatır — startup config check + exponential backoff retry
pub fn init() {
    std::thread::spawn(|| {
        // Kısa bir gecikme — uygulamanın diğer init adımlarının tamamlanmasını bekle
        std::thread::sleep(Duration::from_secs(2));
        startup_config_check();
    });
}

/// API'den güncel sunucu config'ini çeker ve uygular
fn startup_config_check() {
    let api_server = get_api_server_url();
    if api_server.is_empty() {
        log::debug!("key_recovery: no API server configured, skipping");
        return;
    }

    let url = format!("{}/api/server-key", api_server.trim_end_matches('/'));
    log::info!("key_recovery: fetching config from {}", url);

    match fetch_server_config(&url) {
        Ok(config) => {
            apply_config(&config);
            log::info!("key_recovery: config applied successfully");
        }
        Err(e) => {
            log::warn!("key_recovery: initial fetch failed: {}, starting recovery", e);
            connection_error_recovery(&api_server);
        }
    }
}

/// Bağlantı hatalarında exponential backoff ile tekrar dener (5s, 15s, 45s)
fn connection_error_recovery(api_server: &str) {
    let backoff_secs = [5u64, 15, 45];
    let url = format!("{}/api/server-key", api_server.trim_end_matches('/'));

    for (attempt, delay) in backoff_secs.iter().enumerate() {
        log::info!(
            "key_recovery: retry {}/{} in {}s",
            attempt + 1,
            backoff_secs.len(),
            delay
        );
        std::thread::sleep(Duration::from_secs(*delay));

        match fetch_server_config(&url) {
            Ok(config) => {
                apply_config(&config);
                log::info!("key_recovery: config recovered on retry {}", attempt + 1);
                return;
            }
            Err(e) => {
                log::warn!("key_recovery: retry {} failed: {}", attempt + 1, e);
            }
        }
    }
    log::error!("key_recovery: all retries exhausted, using existing config");
}

/// HTTP GET ile /api/server-key'den config çeker
fn fetch_server_config(url: &str) -> Result<ServerKeyResponse, Box<dyn std::error::Error>> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(5))
        .build()?;

    let resp = client.get(url).send()?;

    if !resp.status().is_success() {
        return Err(format!("HTTP {}", resp.status()).into());
    }

    let config: ServerKeyResponse = resp.json()?;

    if config.id_server.is_empty() && config.key.is_empty() {
        return Err("Empty config received from server".into());
    }

    Ok(config)
}

/// Çekilen config'i RustDesk options'a yazar
/// custom_.txt (HARD_SETTINGS) varsa o daha yüksek önceliğe sahip kalır
fn apply_config(config: &ServerKeyResponse) {
    let mut options = Config::get_options();
    let mut changed = false;

    if !config.id_server.is_empty() {
        let current = options.get("custom-rendezvous-server").cloned().unwrap_or_default();
        if current != config.id_server {
            options.insert("custom-rendezvous-server".to_owned(), config.id_server.clone());
            changed = true;
            log::info!("key_recovery: id_server updated to {}", config.id_server);
        }
    }

    if !config.relay.is_empty() {
        let current = options.get("relay-server").cloned().unwrap_or_default();
        if current != config.relay {
            options.insert("relay-server".to_owned(), config.relay.clone());
            changed = true;
            log::info!("key_recovery: relay updated to {}", config.relay);
        }
    }

    if !config.api_server.is_empty() {
        let current = options.get("api-server").cloned().unwrap_or_default();
        if current != config.api_server {
            options.insert("api-server".to_owned(), config.api_server.clone());
            changed = true;
            log::info!("key_recovery: api_server updated to {}", config.api_server);
        }
    }

    if !config.key.is_empty() {
        let current = options.get("key").cloned().unwrap_or_default();
        if current != config.key {
            options.insert("key".to_owned(), config.key.clone());
            changed = true;
            log::info!("key_recovery: key updated");
        }
    }

    if changed {
        Config::set_options(options);
    }
}

/// Mevcut API server URL'ini çeşitli kaynaklardan belirler
fn get_api_server_url() -> String {
    // 1. HARD_SETTINGS'den (custom_.txt root key'leri)
    if let Some(api) = hbb_common::config::HARD_SETTINGS
        .read()
        .unwrap()
        .get("api-server")
    {
        if !api.is_empty() {
            return api.clone();
        }
    }

    // 2. OVERWRITE_SETTINGS'den (custom_.txt override-settings)
    if let Some(api) = hbb_common::config::OVERWRITE_SETTINGS
        .read()
        .unwrap()
        .get("api-server")
    {
        if !api.is_empty() {
            return api.clone();
        }
    }

    // 3. Kullanıcı options'dan (RustDesk.toml)
    let api = Config::get_option("api-server");
    if !api.is_empty() {
        return api;
    }

    // 4. custom-rendezvous-server'dan türet (port - 2)
    let rendezvous = Config::get_option("custom-rendezvous-server");
    if !rendezvous.is_empty() {
        let s = crate::common::increase_port(&rendezvous, -2);
        if s == rendezvous {
            return format!("http://{}:{}", s, hbb_common::config::RENDEZVOUS_PORT - 2);
        } else {
            return format!("http://{}", s);
        }
    }

    // 5. AcilBir fallback
    "https://acilbir.com".to_owned()
}
