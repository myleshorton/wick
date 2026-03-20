package fetch

import (
	"io"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/temoto/robotstxt"
)

var robotsCache = &rCache{entries: make(map[string]*rEntry)}

const robotsTTL = 1 * time.Hour

type rCache struct {
	mu      sync.RWMutex
	entries map[string]*rEntry
}

type rEntry struct {
	data      *robotstxt.RobotsData
	fetchedAt time.Time
}

// CheckRobots returns true if the URL is allowed by robots.txt.
// Checks both the "Wick" and "*" user agents.
// Returns true (allowed) if robots.txt can't be fetched.
func CheckRobots(client *http.Client, targetURL string) (bool, error) {
	u, err := url.Parse(targetURL)
	if err != nil {
		return false, err
	}

	host := u.Scheme + "://" + u.Host
	data, err := getRobotsData(client, host)
	if err != nil {
		return true, nil // can't fetch robots.txt → allow
	}

	// Check the "Wick" agent first, then fall back to "*"
	if group := data.FindGroup("Wick"); !group.Test(u.Path) {
		return false, nil
	}
	if group := data.FindGroup("*"); !group.Test(u.Path) {
		return false, nil
	}
	return true, nil
}

func getRobotsData(client *http.Client, host string) (*robotstxt.RobotsData, error) {
	robotsCache.mu.RLock()
	entry, ok := robotsCache.entries[host]
	robotsCache.mu.RUnlock()

	if ok && time.Since(entry.fetchedAt) < robotsTTL {
		return entry.data, nil
	}

	resp, err := client.Get(host + "/robots.txt")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		// No robots.txt → allow everything
		data, _ := robotstxt.FromBytes([]byte(""))
		cacheRobots(host, data)
		return data, nil
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	data, err := robotstxt.FromBytes(body)
	if err != nil {
		return nil, err
	}

	cacheRobots(host, data)
	return data, nil
}

func cacheRobots(host string, data *robotstxt.RobotsData) {
	robotsCache.mu.Lock()
	robotsCache.entries[host] = &rEntry{data: data, fetchedAt: time.Now()}
	robotsCache.mu.Unlock()
}
