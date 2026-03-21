use anyhow::Result;
use std::time::Instant;

use crate::engine::Client;
use crate::extract::{self, Format};
use crate::robots;

pub struct FetchResult {
    pub content: String,
    pub title: Option<String>,
    pub url: String,
    pub status_code: u16,
    pub timing_ms: u64,
}

/// Full fetch pipeline: validate → robots.txt → HTTP request → extract.
pub async fn fetch(
    client: &Client,
    url: &str,
    format: Format,
    respect_robots: bool,
) -> Result<FetchResult> {
    let start = Instant::now();

    let parsed = url::Url::parse(url)
        .map_err(|e| anyhow::anyhow!("invalid URL: {}", e))?;

    match parsed.scheme() {
        "http" | "https" => {}
        s => anyhow::bail!("unsupported scheme {:?} (only http and https)", s),
    }

    if parsed.host_str().is_none() {
        anyhow::bail!("missing host in URL");
    }

    // robots.txt check
    if respect_robots && !robots::check(client, url).await {
        return Ok(FetchResult {
            content: format!(
                "Blocked by robots.txt: {} disallows this path for automated agents.\n\
                 Use respect_robots=false to override (the user takes responsibility).",
                parsed.host_str().unwrap_or("")
            ),
            title: None,
            url: url.to_string(),
            status_code: 0,
            timing_ms: start.elapsed().as_millis() as u64,
        });
    }

    let resp = client.get(url).await?;
    let status = resp.status;
    let body = resp.body;

    if status == 403 || status == 503 {
        if is_challenge(&body) {
            return Ok(FetchResult {
                content: "This page returned a CAPTCHA or browser challenge. \
                          The content could not be extracted automatically."
                    .to_string(),
                title: None,
                url: url.to_string(),
                status_code: status,
                timing_ms: start.elapsed().as_millis() as u64,
            });
        }
        return Ok(FetchResult {
            content: format!("HTTP {}: {}", status, body),
            title: None,
            url: url.to_string(),
            status_code: status,
            timing_ms: start.elapsed().as_millis() as u64,
        });
    }

    if status >= 400 {
        return Ok(FetchResult {
            content: format!("HTTP {}: {}", status, body),
            title: None,
            url: url.to_string(),
            status_code: status,
            timing_ms: start.elapsed().as_millis() as u64,
        });
    }
    // Check if the page needs JS rendering (SPA shell, minimal content)
    let extracted = extract::extract(&body, &parsed, format)?;

    if needs_js_rendering(&extracted.content) && crate::cef::is_available() {
        // Retry with CEF renderer for full JS execution
        match crate::cef::render(url).await {
            Ok(rendered_html) => {
                let re_extracted = extract::extract(&rendered_html, &parsed, format)?;
                return Ok(FetchResult {
                    content: re_extracted.content,
                    title: re_extracted.title.or(extracted.title),
                    url: url.to_string(),
                    status_code: status,
                    timing_ms: (start.elapsed().as_millis()) as u64,
                });
            }
            Err(e) => {
                tracing::warn!("CEF rendering failed, using Cronet result: {}", e);
            }
        }
    }

    Ok(FetchResult {
        content: extracted.content,
        title: extracted.title,
        url: url.to_string(),
        status_code: status,
        timing_ms: start.elapsed().as_millis() as u64,
    })
}

/// Detect pages that likely need JavaScript rendering.
fn needs_js_rendering(content: &str) -> bool {
    let trimmed = content.trim();
    // Very short content after extraction suggests a JS SPA shell
    if trimmed.len() < 100 {
        return true;
    }
    // Common SPA loading indicators
    let lower = trimmed.to_lowercase();
    lower.contains("loading...") || lower.contains("please enable javascript")
}

fn is_challenge(body: &str) -> bool {
    let lower = body.to_lowercase();
    [
        "challenges.cloudflare.com",
        "cf-browser-verification",
        "just a moment...",
        "checking your browser",
        "google.com/recaptcha",
        "hcaptcha.com",
    ]
    .iter()
    .any(|sig| lower.contains(sig))
}
