package session

import (
	"os"
	"path/filepath"
)

// StoragePath returns the default Wick data directory.
func StoragePath() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".wick", "data")
}

// ClearSession removes all persistent data (cookies, cache) and
// recreates the directory.
func ClearSession() error {
	path := StoragePath()
	if err := os.RemoveAll(path); err != nil {
		return err
	}
	return os.MkdirAll(path, 0700)
}
