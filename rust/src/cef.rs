use anyhow::{bail, Result};
use std::path::PathBuf;
use tokio::process::Command;

/// Render a page using the CEF renderer subprocess.
/// Returns the fully-rendered HTML after JavaScript execution.
pub async fn render(url: &str) -> Result<String> {
    let renderer_path = find_renderer()?;

    let output = Command::new(&renderer_path)
        .arg(url)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .output()
        .await
        .map_err(|e| anyhow::anyhow!(
            "failed to start wick-renderer at {:?}: {}. Run 'wick setup --with-js' to install CEF.",
            renderer_path, e
        ))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("wick-renderer failed (exit {}): {}", output.status, stderr.trim());
    }

    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

/// Check if CEF renderer is available.
pub fn is_available() -> bool {
    find_renderer().is_ok()
}

fn find_renderer() -> Result<PathBuf> {
    // Search order: next to wick binary, ~/.wick/cef/, PATH
    let locations = [
        std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.join("wick-renderer"))),
        std::env::var_os("HOME")
            .map(|h| PathBuf::from(h).join(".wick").join("cef").join("wick-renderer")),
    ];

    for loc in locations.iter().flatten() {
        if loc.exists() {
            return Ok(loc.clone());
        }
    }

    // Try PATH
    if let Ok(output) = std::process::Command::new("which")
        .arg("wick-renderer")
        .output()
    {
        if output.status.success() {
            let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !path.is_empty() {
                return Ok(PathBuf::from(path));
            }
        }
    }

    bail!("wick-renderer not found. Run 'wick setup --with-js' to install CEF for JavaScript rendering.")
}
