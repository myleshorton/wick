//go:build with_purego

package engine

import (
	"fmt"
	"runtime"

	cronet "github.com/sagernet/cronet-go"
)

func loadCronetLibrary() error {
	if err := cronet.LoadLibrary(""); err != nil {
		return fmt.Errorf("cronet library not found.\n\n"+
			"Wick requires libcronet (%s) to be installed.\n"+
			"  Linux/Windows: run scripts/download-libcronet.sh\n"+
			"  macOS:         build from source (see DESIGN.md)\n\n"+
			"Place the library next to the wick binary or in a standard library path.\n"+
			"Original error: %w", libraryName(), err)
	}
	return nil
}

func libraryName() string {
	switch runtime.GOOS {
	case "darwin":
		return "libcronet.dylib"
	case "windows":
		return "libcronet.dll"
	default:
		return "libcronet.so"
	}
}
