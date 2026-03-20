package engine

import (
	"strings"
	"testing"
)

func TestChromeUserAgent(t *testing.T) {
	ua := ChromeUserAgent()
	if !strings.Contains(ua, "Chrome/") {
		t.Errorf("expected Chrome UA, got: %s", ua)
	}
	if !strings.Contains(ua, "Mozilla/5.0") {
		t.Errorf("expected Mozilla prefix, got: %s", ua)
	}
}

func TestChromeHeaders(t *testing.T) {
	h := ChromeHeaders("https://example.com")

	required := []string{
		"Accept",
		"Accept-Language",
		"Sec-Ch-Ua",
		"Sec-Ch-Ua-Mobile",
		"Sec-Ch-Ua-Platform",
		"Sec-Fetch-Dest",
		"Sec-Fetch-Mode",
		"Sec-Fetch-Site",
		"Upgrade-Insecure-Requests",
	}

	for _, key := range required {
		if h.Get(key) == "" {
			t.Errorf("missing header: %s", key)
		}
	}

	if !strings.Contains(h.Get("Sec-Ch-Ua"), "Chrome") {
		t.Errorf("Sec-Ch-Ua should mention Chrome, got: %s", h.Get("Sec-Ch-Ua"))
	}
}
