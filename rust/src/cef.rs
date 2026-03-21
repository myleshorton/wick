use anyhow::{bail, Result};
use std::path::PathBuf;
use std::time::Duration;
use tokio::process::Command;

const RENDER_TIMEOUT: Duration = Duration::from_secs(30);

/// Render a page using the CEF renderer subprocess.
/// Returns the fully-rendered HTML after JavaScript execution.
pub async fn render(url: &str) -> Result<String> {
    // Clean up stale CEF cache directories from previous runs.
    // CEF single-process mode uses singleton locks that prevent reuse.
    // Brief delay lets the OS fully release resources from a prior renderer.
    cleanup_cef_caches();
    tokio::time::sleep(Duration::from_millis(500)).await;

    let renderer_path = find_renderer()?;

    // The renderer needs the CEF framework accessible at
    // @executable_path/../Frameworks/Chromium Embedded Framework.framework
    let output = tokio::time::timeout(
        RENDER_TIMEOUT,
        Command::new(&renderer_path)
            .arg(url)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .output(),
    )
    .await
    .map_err(|_| anyhow::anyhow!("CEF rendering timed out after {}s", RENDER_TIMEOUT.as_secs()))?
    .map_err(|e| {
        anyhow::anyhow!(
            "failed to start wick-renderer at {:?}: {}. \
             Run 'wick setup --with-js' to install CEF.",
            renderer_path,
            e
        )
    })?;

    let html = String::from_utf8_lossy(&output.stdout).into_owned();

    // CEF sometimes crashes during shutdown (cef_shutdown SIGTRAP) even though
    // rendering succeeded. Accept the output if we got HTML regardless of exit code.
    if !html.is_empty() {
        return Ok(html);
    }

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!(
            "wick-renderer failed (exit {}): {}",
            output.status,
            stderr.trim()
        );
    }

    bail!("wick-renderer returned empty output")
}

/// Check if CEF renderer is available.
pub fn is_available() -> bool {
    find_renderer().is_ok()
}

fn find_renderer() -> Result<PathBuf> {
    // Search for wick-renderer.app bundle (multi-process mode) or bare binary.
    // The .app bundle is required for macOS multi-process CEF.
    let locations = [
        // .app bundle next to wick binary
        std::env::current_exe().ok().and_then(|p| {
            p.parent().map(|d| {
                d.join("wick-renderer.app/Contents/MacOS/wick-renderer")
            })
        }),
        // Bare binary next to wick (single-process fallback)
        std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(|d| d.join("wick-renderer"))),
        // User install location
        std::env::var_os("HOME")
            .map(|h| PathBuf::from(h).join(".wick").join("cef").join(
                "wick-renderer.app/Contents/MacOS/wick-renderer"
            )),
    ];

    for loc in locations.iter().flatten() {
        if loc.exists() {
            return Ok(loc.clone());
        }
    }

    // Try PATH
    if let Ok(p) = which("wick-renderer") {
        return Ok(p);
    }

    bail!(
        "wick-renderer not found. \
         Run 'wick setup --with-js' to install CEF for JavaScript rendering."
    )
}

fn cleanup_cef_caches() {
    if let Some(home) = std::env::var_os("HOME") {
        let wick_dir = PathBuf::from(home).join(".wick");
        if let Ok(entries) = std::fs::read_dir(&wick_dir) {
            for entry in entries.flatten() {
                if let Some(name) = entry.file_name().to_str() {
                    if name.starts_with("cef-cache-") {
                        let _ = std::fs::remove_dir_all(entry.path());
                    }
                }
            }
        }
    }
}

fn which(name: &str) -> Result<PathBuf> {
    let output = std::process::Command::new("which")
        .arg(name)
        .output()?;
    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !path.is_empty() {
            return Ok(PathBuf::from(path));
        }
    }
    bail!("{} not on PATH", name)
}
