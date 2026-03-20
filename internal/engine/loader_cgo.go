//go:build !with_purego

package engine

// CGO mode: library is linked at compile time, no runtime loading needed.
func loadCronetLibrary() error {
	return nil
}
