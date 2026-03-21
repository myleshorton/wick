use anyhow::Result;
use reqwest::header::{HeaderMap, HeaderValue};

/// Chrome version must match the Cronet/Chromium version (143).
const CHROME_MAJOR: &str = "143";
const CHROME_FULL: &str = "143.0.7499.109";

/// HTTP client with Chrome-equivalent headers.
/// Currently uses reqwest; will be replaced with Cronet FFI.
pub struct Client {
    inner: reqwest::Client,
}

impl Client {
    pub fn new() -> Result<Self> {
        let client = reqwest::Client::builder()
            .user_agent(chrome_user_agent())
            .default_headers(chrome_headers())
            .gzip(true)
            .brotli(true)
            .deflate(true)
            .timeout(std::time::Duration::from_secs(30))
            .build()?;
        Ok(Self { inner: client })
    }

    pub async fn get(&self, url: &str) -> Result<reqwest::Response> {
        Ok(self.inner.get(url).send().await?)
    }

    pub fn inner(&self) -> &reqwest::Client {
        &self.inner
    }
}

pub fn chrome_user_agent() -> String {
    format!(
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) \
         AppleWebKit/537.36 (KHTML, like Gecko) \
         Chrome/{CHROME_FULL} Safari/537.36"
    )
}

pub fn chrome_headers() -> HeaderMap {
    let mut h = HeaderMap::new();
    h.insert("Accept", HeaderValue::from_static(
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    ));
    h.insert("Accept-Language", HeaderValue::from_static("en-US,en;q=0.9"));
    h.insert("Accept-Encoding", HeaderValue::from_static("gzip, deflate, br, zstd"));
    h.insert("Cache-Control", HeaderValue::from_static("max-age=0"));
    h.insert(
        "Sec-Ch-Ua",
        HeaderValue::from_str(&format!(
            r#""Chromium";v="{CHROME_MAJOR}", "Google Chrome";v="{CHROME_MAJOR}", "Not:A-Brand";v="24""#
        ))
        .unwrap(),
    );
    h.insert("Sec-Ch-Ua-Mobile", HeaderValue::from_static("?0"));
    h.insert("Sec-Ch-Ua-Platform", HeaderValue::from_static("\"macOS\""));
    h.insert("Sec-Fetch-Dest", HeaderValue::from_static("document"));
    h.insert("Sec-Fetch-Mode", HeaderValue::from_static("navigate"));
    h.insert("Sec-Fetch-Site", HeaderValue::from_static("none"));
    h.insert("Sec-Fetch-User", HeaderValue::from_static("?1"));
    h.insert("Upgrade-Insecure-Requests", HeaderValue::from_static("1"));
    h
}
